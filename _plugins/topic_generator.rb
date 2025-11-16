# _plugins/topic-generator.rb
module Jekyll
  class TopicPage < Page
    def initialize(site, base, topic)
      @site = site
      @base = base
      @dir  = "topics/#{topic['id']}"
      @name = "index.html"

      process(@name)
      read_yaml(File.join(base, "_layouts"), "topic.html")

      # Front matter variables
      self.data['layout'] = "topic"
      self.data['topic'] = topic 
      self.data['title'] = topic['title']
    end
  end

  class TopicIndexPage < Page
    def initialize(site, base, topics)
      @site = site
      @base = base
      @dir  = "topics"
      @name = "index.html"

      process(@name)
      read_yaml(File.join(base, "_layouts"), "topics.html")

      self.data['layout'] = "topics"
      self.data['topics'] = topics 
      self.data['title'] = "Topics"
    end
  end

  class TopicGenerator < Generator
    safe true
    priority :normal

    def generate(site)
      topics = site.data['topics'] || []

      site.pages << TopicIndexPage.new(site, site.source, topics)

      topics.each do |topic|
        site.pages << TopicPage.new(site, site.source, topic)
      end
    end
  end
end