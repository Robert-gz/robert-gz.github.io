FROM jekyll/jekyll
COPY . /srv/jekyll
RUN cd /srv/jekyll && bundle install 