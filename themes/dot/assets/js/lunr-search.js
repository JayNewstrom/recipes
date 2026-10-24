(function ($) {
    'use strict';

    var lunrIndex,
        $results,
        pagesIndex,
        pagesByHref = {};

    // Register a pipeline function that indexes both the original word and its stemmed version.
    // This allows exact full-word searches (e.g. "chipotle") and prefix searches on full words (e.g. "chocola*")
    // to match even when Lunr's stemmer reduces the word to a shorter stem (e.g. "chipotl", "chocol").
    var stemmerWithOriginal = function (token) {
        var original = token.clone();
        var stemmed = lunr.stemmer(token);
        if (stemmed.toString() === original.toString()) {
            return original;
        }
        return [original, stemmed];
    };
    lunr.Pipeline.registerFunction(stemmerWithOriginal, 'stemmerWithOriginal');

    function initLunr() {
        $.getJSON("/json/index.json")
            .done(function (index) {
                pagesIndex = index;
                pagesByHref = {};
                pagesIndex.forEach(function (page) {
                    pagesByHref[page.href] = page;
                });

                // Set up lunrjs by declaring the fields we use
                // Also provide their boost level for the ranking
                lunrIndex = lunr(function () {
                    this.pipeline.remove(lunr.stemmer);
                    this.pipeline.add(stemmerWithOriginal);
                    this.searchPipeline.remove(lunr.stemmer);
                    this.searchPipeline.add(stemmerWithOriginal);

                    this.field("title", {
                        boost: 10
                    });
                    this.field("tags", {
                        boost: 5
                    });
                    this.field("content");

                    // ref is the result item identifier (I chose the page URL)
                    this.ref("href");

                    // Feed lunr with each file and let lunr actually index them
                    pagesIndex.forEach((page) => {
                        this.add(page);
                    });
                });
            })
            .fail(function (jqxhr, textStatus, error) {
                var err = textStatus + ", " + error;
                console.error("Error getting Hugo index flie:", err);
            });
    }

    function initUI() {
        $results = $("#results");
        $("#search").keyup(function () {
            $results.empty();

            // Only trigger a search when 2 chars. at least have been provided
            var query = $(this).val().trim();
            if (query.length < 2) {
                return;
            }

            var results = search(query);

            renderResults(results);
        });
    }

    /**
     * Trigger a search in lunr and transform the result
     *
     * @param  {String} query
     * @return {Array}  results
     */
    function search(query) {
        if (!lunrIndex) {
            return [];
        }

        var tokens = lunr.tokenizer(query);
        var terms = [];
        tokens.forEach(function (token) {
            var term = lunr.trimmer(token).toString().toLowerCase();
            if (term) {
                terms.push(term);
            }
        });

        if (!terms.length) {
            return [];
        }

        try {
            var results = lunrIndex.query(function (q) {
                terms.forEach(function (term) {
                    // Exact / stemmed match with higher boost
                    q.term(term, { boost: 10 });
                    // Trailing wildcard for prefix matching as the user types
                    q.term(term, {
                        wildcard: lunr.Query.wildcard.TRAILING,
                        boost: 1
                    });
                });
            });

            return results.map(function (result) {
                return pagesByHref[result.ref];
            }).filter(Boolean);
        } catch (err) {
            console.error("Lunr search error:", err);
            return [];
        }
    }

    /**
     * Display the 10 first results
     *
     * @param  {Array} results to display
     */
    function renderResults(results) {
        if (!results.length) {
            return;
        }

        const $search = $("#search");
        $results.css({
            position: "absolute",
            backgroundColor: "white",
            class: "dropdown-menu",
            top: $search.position().bottom,
            left: $search.position().left
        });        

        // Only show the ten first results
        results.slice(0, 10).forEach(function (result) {
            var $result = $("<a>", {
                class: "d-block pl-3 pr-3 p-1",
                href: result.href,
                text: result.title
            });
            $results.append($result);
        });
    }

    initLunr();
    initUI();
})(jQuery);
