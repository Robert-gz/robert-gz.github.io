 
 docker run --rm -it -v `pwd`:/srv/jekyll --net=host robertxie/robert-gz.github.io  bash
jekyll build

jekyll serve
