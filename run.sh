docker run --rm -it -v `pwd`:/srv/jekyll -p 4000:4000 -p 8808:8808  10.0.2.50/xiehq/jekyll   bash
#bash


docker run --rm -it -v `pwd`:/srv/jekyll -p 4000:4000 -p 8808:8808  robertxie/robert-gz.github.io bash
jekyll serve
