# Recipes
I've been frustrated by a lot of recipe websites for many reasons. 
This is my recipe website, built for me. 
A lot of these recipes have origins from other places, but have been modified to how I make things, and what I make them with.

## Developing
This website uses [hugo](https://gohugo.io/).
Install hugo on your local machine using the instructions from the website.

#### Testing locally
`hugo server`

#### Adding a new recipe
`hugo new recipe-name.md`

## Deploying
This website is deployed on AWS using Terraform and Github Actions. For more information see [aws](/aws).

## License
Where not otherwise noted, code is licensed under Apache 2.0

    Copyright 2020 Jay Newstrom

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
