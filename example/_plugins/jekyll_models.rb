#------------------------------------------------------------------------
# encoding: utf-8
# @(#)jekyll_models.rb      1.00 20-Jun-2012 17:00
#
# Copyright (c) 2012 Kyle Paulsen. All Rights Reserved.
# Licensed under the MIT license (http://www.opensource.org/licenses/mit-license.php)
#
# Description:  A generator that allows the user to make more jekyll objects
#               like posts. It reads in YAML files from the specified directories
#               and puts all of the information into the global site variable
#               for easy access. It can also generate Model pages.
#
# Included filters : (none)
#
# Usage:
#   Put jekyll_models.rb in your _plugins directory.
#   Edit your _config.yml to have a jekyll_models property (For this example, I will set it
#     to [projects, tests]
#   Make the coorisponding model directories in the webroot. Don't forget the leading 
#     underscore (I made the dirs: _projects and _tests )
#   Add the required templates to each directory:
#     - the index.html template is assumed to be used for the list page of whatever model
#         dir it is in. It must also be named index.html however it doesnt have to be
#         generated that way (see the jekyll_models_urls setting)
#     - the template.html template is used to help generate each model. It is sent the page
#         var with model defined on it to represent the current generating model.
#         So for example, in template.html I could do {{ page.model.name }}.
#         template.html should be created with that exact name unless you are specifing 
#         a different template to use in every model YAML file. (see the template setting)
#     Templates can also use YAML front matter!
#   Make some model YAML files in the model directories. These files must end with:
#     ( .txt or .yml or .yaml or .textile ) or else they will be ignored. These files are 
#     just plain old YAML files and can contain whatever you want.
#   Generate your pages like normal! Your models will be generated and all the model objects
#     will be attached to your global site var (like site.cars) for every page.
#
# Available _config.yml settings :
# - jekyll_models:         Required! A list of the users' model types. These need matching
#                          directories with an underscore prefix under the web root. 
#                          (Ex. jekyll_models: [Projects, Albums, Cars]
#
# - jekyll_models_generate_pages: 
#                          Should JekyllModels generate model pages? (true | false)
#                          Default value: true
#
# - jekyll_models_urls:    How Should JekyllModels organize generated models? 
#                          rest-like = webroot.com/cars/jeep/index.html
#                                      (with cars/index.html for the list page)
#                          models    = webroot.com/cars/jeep.html 
#                                      (with cars/index.html for the list page)
#                          base      = webroot.com/jeep.html
#                                      (with webroot.com/cars.html for the list page)
#                          default: rest-like
#
# - site_base:             The url of the webroot. (ex http://www.mydomain.com/ )
#                          If this is provided, JekyllModels can put each models'
#                          absolute url in "mdl_url" in its own object. This is for 
#                          convenience when hyperlinking to models.
#
# Model Structure and Meaning:
# In each model YAML file, some properties can be set to customize behaviour.
# Other properties are automatically set. Here is a list of what's available:
#
# timestamp:               You may set your own time to be sent in to jekyll like how 
#                          posts have their time derived from their filename. 
#                          This will be most usefull for sorting. YYYY-MM-DD is supported.
#                          If not specified, the YAML file modification date is used.
#
# mdl_name:                This is automatically set by JekyllModels to match the YAML
#                          filename without the extension. This is used for generation.
#
# mdl_type:                This is automatically set by JekyllModels to match the directory
#                          that the YAML file is in. (without the underscore prefix). This
#                          is used for generation.
#
# mdl_url:                 If site_base is defined in _config.yml then this will automatically
#                          be set to the absolute url of this model's generated page.
#
# template:                You may specify what template this model should use to help
#                          generate it. For example, if you have the template "car_temp.html"
#                          then you can set this to "car_temp". Do not include ".html".
#                          By default, this is set to "template"
#
# Update History: (most recent first)
# 20-Jun-2012 kyle paulsen -- First public release.
#------------------------------------------------------------------------

module JekyllModels
  
  # A class for reading in all the model YAML defs and putting them in the global site
  # var for every page to see.
  class ModelLoader
    
    attr_accessor :config
    
    def initialize(config)
      if !config['jekyll_models']
        puts "ModelLoader: there are no models defined in the _config.yml! Aborting!"
        return
      end
      
      self.config = config
      dirs = config['jekyll_models']
      
      #make sure site base has a / on the end.
      if self.config["site_base"]
        if self.config["site_base"][-1,1] != "/"
          self.config["site_base"] += "/"
        end
      end
      
      #set default value for generating pages
      self.config["jekyll_models_generate_pages"] = self.config["jekyll_models_generate_pages"] || "true"
      
      #set default value for generation location style.
      self.config["jekyll_models_urls"] = self.config["jekyll_models_urls"] || "rest-like"
      
      #read in model YAML files...
      dirs.each do |dir|
        config[dir] = read_directory(dir, File.join(config['source'], "_"+dir))
      end
    end
    
    def read_directory(mdl_name, dir)
      models = []
      entries = Dir.chdir(dir) { filter_entries(Dir.entries('.')) }

      entries.each do |f|
        f_abs = File.join(dir, f)
        if !File.directory?(f_abs) && !File.symlink?(f_abs)
          new_mdl = YAML.load_file(f_abs)
          
          # set model data...
          parts = f.split(".")
          new_mdl["mdl_name"] = File.basename(f, "."+parts.last)
          new_mdl["mdl_type"] = mdl_name
          
          if new_mdl["timestamp"]
            new_mdl["timestamp"] = new_mdl["timestamp"].to_time
          else
            new_mdl["timestamp"] = File.mtime(f_abs)
          end
          
          if self.config["site_base"]
            new_mdl["mdl_url"] = self.config["site_base"]
            new_mdl["mdl_url"] += case self.config['jekyll_models_urls']
            when "rest-like"
              "#{new_mdl["mdl_type"]}/#{new_mdl["mdl_name"]}"
            when "models"
              "#{new_mdl["mdl_type"]}/#{new_mdl["mdl_name"]}.html"
            when "base"
              "#{new_mdl["mdl_name"]}.html"
            else
              "#{new_mdl["mdl_type"]}/#{new_mdl["mdl_name"]}"
            end
          end
          
          models << new_mdl
        end
      end
      return models
    end
    
    def filter_entries(entries)
      entries = entries.reject do |e|
        ext = File.extname(e)
        (ext != ".txt" && ext != ".yml" && ext != ".yaml") ||
        ['.', '_', '#'].include?(e[0..0]) ||
        e[-1..-1] == '~' ||
        File.symlink?(e)
      end
    end
    
  end
  
  # Pretty much this entire class was borrowed from Jim Pravetz's product_generator plugin.
  # I found his blog here: http://jimpravetz.com/blog/2011/12/generating-jekyll-pages-from-data/
  # He is awesome for putting his code up on the web.
  class ModelPage < ::Jekyll::Page
    
    # The resultant relative URL of where the published file will end up
    # Added for use by a sitemap generator
    attr_accessor :dest_url
    # The last modified date to be used for web caching of this file.
    # Derived from latest date of products.json and template files
    # Added for use by a sitemap generator
    attr_accessor :src_mtime

    # Initialize a new Page.
    #
    # site - The Site object.
    # base - The String path to the source.
    # dest_dir  - The String path between the dest and the file.
    # dest_name - The String name of the destination file (e.g. index.html or myproduct.html)
    # src_dir  - The String path between the source and the file.
    # src_name - The String filename of the source page file 
    # data_mtime - mtime of the products.json data file, used for sitemap generator
    def initialize(site, base, dest_dir, dest_name, src_dir, src_name, data_mtime )
      @site = site
      @base = base
      @dir  = dest_dir
      @dest_dir = dest_dir
      @dest_name = dest_name
      @dest_url = File.join( '/', dest_dir ) 
      @src_mtime = data_mtime

      src_name_with_ext = File.join(base, src_dir, src_name)
      
      @name = src_name_with_ext
      self.process(src_name_with_ext)
      
      # Read the YAML from the specified page
      self.read_yaml(File.join(base, src_dir), src_name )
      
      # Remember the mod time, used for site_map
      file_mtime = File.mtime( File.join(base, src_dir, src_name) )
      @src_mtime = file_mtime if file_mtime > @src_mtime
    end

    # Override to set url properly
    def to_liquid
      self.data.deep_merge({
        "url"        => @dest_url,
        "content"    => self.content })
    end

    # Override so that we can control where the destination file goes
    def destination(dest)
      # The url needs to be unescaped in order to preserve the correct filename.
      path = File.join(dest, @dest_dir, @dest_name )
      path = File.join(path, "index.html") if self.url =~ /\/$/
      path
    end

  end
  
  class ::Jekyll::ProductGenerator < ::Jekyll::Generator
    safe true
    
    def initialize(config)
      #start loadin those YAML files now!
      ModelLoader.new(config)
    end
    
    def generate(site)
      if site.config['jekyll_models_generate_pages'] && site.config['jekyll_models']
        puts "ModelLoader: Building model pages!"
        mdls = site.config['jekyll_models']
        mdls.each do |mdl|
          write_model_index(site, mdl)
          write_model_instance_indexes(site, mdl)
        end
      end
    end
    
    #writes the list page for this model type
    def write_model_index(site, model_name)
      case site.config["jekyll_models_urls"]
      when "base"
        index = ModelPage.new(site, site.config['source'], "", model_name+'.html', "_"+model_name, 'index.html', Time.parse("1900-01-01"))
      else
        index = ModelPage.new(site, site.config['source'], model_name, 'index.html', "_"+model_name, 'index.html', Time.parse("1900-01-01"))
      end
      
      index.render(site.layouts, site.site_payload)
      index.write(site.dest)
      # Record the fact that this page has been added, otherwise Site::cleanup will remove it.
      site.pages << index
    end
    
    #writes each model page and sends in the model through page.model
    def write_model_instance_indexes(site, model_name)
      models = site.config[model_name]
      models.each do |mdl|
        template_file = 'template.html'
        if mdl['template']
          template_file = mdl['template'] + ".html"
        end
        
        case site.config["jekyll_models_urls"]
        when "rest-like"
          index = ModelPage.new(site, site.config['source'], File.join(model_name, mdl['mdl_name']), 'index.html', "_"+model_name, template_file, mdl['timestamp'])
        when "models"
          index = ModelPage.new(site, site.config['source'], model_name, mdl['mdl_name']+'.html', "_"+model_name, template_file, mdl['timestamp'])
        when "base"
          index = ModelPage.new(site, site.config['source'], "", mdl['mdl_name']+'.html', "_"+model_name, template_file, mdl['timestamp'])
        else
          index = ModelPage.new(site, site.config['source'], File.join(model_name, mdl['mdl_name']), 'index.html', "_"+model_name, template_file, mdl['timestamp'])
        end
        
        index.data['model'] = mdl
        
        index.render(site.layouts, site.site_payload)
        index.write(site.dest)
        # Record the fact that this page has been added, otherwise Site::cleanup will remove it.
        site.pages << index
      end
    end
  end
  
end
