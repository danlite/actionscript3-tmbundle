#!/usr/bin/env ruby -wKU
# encoding: utf-8

# ActionScript 3 utility methods for inspecting source directories, paths and
# packages.
#
module SourceTools

  # Returns an colon seperated list of directory names
  # that are commonly used as the root directory for source files.
  #
  # See 'Settings' bundle preference to override defaults.
  #
  def self.common_src_dir_list
    src_dirs = ENV['TM_AS3_USUAL_SRC_DIRS']
    src_dirs = "src:lib:source:test" if src_dirs == nil
    src_dirs
  end

  # Returns an array of directory names that are commonly used
  # as the root directory for source files.
  #
  def self.common_src_dirs
    src_dirs_matches = common_src_dir_list.split(":")
    src_dirs_matches
  end


  def self.each_text_file_in_dir(dir, &block)
    TextMate.scan_dir(dir, block, ProjectFileFilter.new)
  end


  # Loads all paths found within the external source directories that have
  # a filename which contains the requested word.
  #
  def self.search_external_libs(word)

    overall_best_paths = []
    overall_package_paths = []

    if ENV['TM_AS3_EXTERNAL_SRCS']
      include TextMate

      lib_list = ENV['TM_AS3_EXTERNAL_SRCS'].split(':')

      lib_list.each do |lib|

        best_paths = []
        package_paths = []

        each_text_file_in_dir(lib) do |file|

          if file =~ /\b#{word}\w*\.(as|mxml)$/

            path = file.sub(lib, "")
            path = truncate_to_src(path)
            path = path.gsub(/\.(as|mxml)$/,'').gsub( "/", ".").sub(/^\./,'')

            if path =~ /\.#{word}$/
              best_paths << path
            else
              package_paths << path
            end

          end

        end

        overall_best_paths += best_paths
        overall_package_paths += package_paths

      end

    end

    { :exact_matches => overall_best_paths, :partial_matches => overall_package_paths }

  end

  # Loads all paths found within the current project that have a filename which
  # contains the requested word.
  #
  def self.search_project_paths(word)

    project = "#{ENV['TM_PROJECT_DIRECTORY']}"

    best_paths = []
    package_paths = []

    # Collect all .as and .mxml files with a filename that contains the search
    # term. When used outside a project this step is skipped.
    TextMate.each_text_file do |file|

      if file =~ /\b#{word}\w*\.(as|mxml)$/

        path = file.sub( project, "")
        path = truncate_to_src(path)
        path = path.gsub(/\.(as|mxml)$/,'').gsub( "/", ".").sub(/^\./,'')

        if path =~ /\.#{word}$/
          best_paths << path
        else
          package_paths << path
        end

      end

    end

    { :exact_matches => best_paths, :partial_matches => package_paths }

  end

  # Loads all paths stored in the bundle lookup that have a filename which
  # contains the requested word.
  #
  def self.search_bundle_paths(word)

    help_toc = File.dirname(__FILE__) + '/../../data/doc_dictionary.xml'

    best_paths = []
    package_paths = []

    # Open Help dictionary and find matching lines
    toc = ::IO.readlines(help_toc)
    toc.each do |line|

      if line =~ /href='([a-zA-Z0-9\/]*\b#{word}\w*)\.html'|([a-zA-Z0-9\/]*\/package\.html##{word}\w*)\(\)'/

        if $2
          path = $2.gsub('package.html#', '').gsub('/', '.')
        else          
            path = $1.gsub('/', '.')
        end

        if path =~ /(^|\.)#{word}$/
          best_paths << path
        else
          package_paths << path
        end

      end
    end

    { :exact_matches => best_paths, :partial_matches => package_paths }

  end

  # Loads both bundle and project paths.
  #
  def self.search_all_paths(word)

    pp = search_project_paths(word)
    bp = search_bundle_paths(word)
    ep = search_external_libs(word)

    e = pp[:exact_matches] + bp[:exact_matches] + ep[:exact_matches]
    p = pp[:partial_matches] + bp[:partial_matches] + ep[:partial_matches]

    e.uniq!
    p.uniq!

    { :exact_matches => e, :partial_matches => p }

  end

  # Takes the path and truncates it to the last matching 'common_src_dir'.
  #
  def self.truncate_to_src(path)
    common_src_dirs.each do |remove|
      path = path.gsub( /^.*\b#{remove}\b(\/|$)/, '' );
    end
    path
  end

  # Finds, and where sucessful returns, the package path for the specified
  # class (word is used as parameter here as it may be a partial class name).
  # Packages paths are resolved via doc_dictionary.xml, which contains flash, fl,
  # and mx paths, and the current tm project (when available).
  #
  # Where mulitple possible matches are found these are presented to the user
  # using Textmate::UI.menu with the most probable match at the top of the menu.
  #
  def self.find_package(word="")

    TextMate.exit_show_tool_tip("Please select a class to\nlocate the package path for.") if word.empty?

    all_paths = search_all_paths(word)

    best_paths = all_paths[:exact_matches]
    package_paths = all_paths[:partial_matches]

    if package_paths.size > 0 and best_paths.size > 0
      package_paths = best_paths + ['-'] + package_paths
    else
      package_paths = best_paths + package_paths
    end

    TextMate.exit_show_tool_tip("Class not found") if package_paths.empty?

    if package_paths.size == 1

      package_paths.pop

    else

      # Move any exact hits to the top of the list.
      best_paths = package_paths.grep( /\.#{word}$/ )

      i = TextMate::UI.menu(package_paths)
      TextMate.exit_discard() if i == nil
      package_paths[i]

    end

  end
  
  # Takes the path paramater and lists all classes found within that directory.
  #
  # Path can be either a package declaration, ie org.helvector.core.* or a file
  # path.
  #
  def self.list_package(path)
    
    #if path is a package declaration convert it to a file path.
    path.gsub!('.','/') unless path =~ /\//
    path.sub!(/\/\*$/,'')
    
    unless File.exist?(path)
      path = ENV['TM_PROJECT_DIRECTORY'] + "/src/" + path
    end
    
    return nil unless File.exist?(path)
    
    classes = []
    
    Dir.foreach(path) do |f|
      classes << File.basename(f,$1) if f =~ /(\.(as|mxml))$/
    end
    
    classes
    
  end
  
end
