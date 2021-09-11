(function ($) {
    'use strict';

    var lunrIndex,
        $results,
        pagesIndex;

    function initLunr() {
        $.getJSON("/json/index.json")
            .done(function (index) {
                pagesIndex = index;

                // Set up lunrjs by declaring the fields we use
                // Also provide their boost level for the ranking
                lunrIndex = lunr(function () {
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
            var query = $(this).val();
            if (query.length < 2) {
                return;
            }

            // add trailing wildcard to give more organic search results
            // we shouldn't need to do this because lunr is supposed to do stemming but alas...
            // stemming: https://lunrjs.com/guides/core_concepts.html
            // https://tartarus.org/martin/PorterStemmer/
            var results = search(`${query}*`);

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
        return lunrIndex.search(query).map(function (result) {
            return pagesIndex.filter(function (page) {
                return page.href === result.ref;
            })[0];
        });
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
