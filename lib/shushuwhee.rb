#
require "shushuwhee/version"
require 'open-uri'
require 'nokogiri'
require 'fileutils'
require 'gepub'
require 'pry'

# for testing: 
# $:<< "./lib/"
# require 'shushuwhee'
# Shushuwhee.read_book("32503", {:output_file_name => "32503", :format => "epub"})
module Shushuwhee
  SHUSHUWEN_URL = "http://www.shushuw.cn/"
  NEWLINE = "\r\n"
  DEBUG_MODE = false

  class << self
    # Finds all the books in book_list and reads them, outputting their
    # content as epub files in the "shu" folder (creates folder if missing).
    def read_many(book_list, output_folder_name="shu", format="epub")
      unless File.exist?(output_folder_name) and File.directory?(output_folder_name)
        FileUtils.mkdir(output_folder_name)
      end
      book_list.each do | book_id |
        book_id = book_id.chomp
        outfile = File.join(output_folder_name, book_id)
        read_book(book_id, {:output_file_name => outfile, :format => format})
      end
    end

    # Shushuwhee.read(book_id)
    # @param opts Possible options include output_file_name, format,
    #   output_folder_name.
    def read_book(book_id, opts = {})
      opts = opts
      debug "Debug: Book #{book_id}"

      tmpdir = Dir.mktmpdir(book_id)
      output_file = nil
      file_name = opts[:output_file_name] || nil
      format = opts[:format] || "html"

      table_of_contents = Nokogiri::HTML(open(table_of_contents_url(book_id)))

      chapters = table_of_contents.css("ul li")

      chapter_list = []

      chapters = chapters[0..2] if debug_mode?
      chapters.each do |chapter|
        debug "Debug:   chapter  #{chapter.children.first.child.text}"
        chapter_text = read_chapter(chapter)
        chapter_id = chapter_id(chapter)
        chapter_title = chapter_title(chapter)

        if format == "html"
          chapter_file_name = file_name
        else
          chapter_file_name = tmpdir + "/#{chapter_id}.xhtml"
        end

        debug "DEBUG: #{chapter_file_name}"
        output_to_file(chapter_text, chapter_file_name)

        chapter_list << {:file => "#{chapter_id}.xhtml", :title => chapter_title}
        printf "."
      end

      if format == "epub"
        builder = create_builder(book_id, tmpdir, chapter_list)
        epub_name = file_name || book_id
        epub_name += ".epub"
        builder.generate_epub(epub_name)
      end

      puts " :)"
    end

    # Returns the chapter text for a given chapter
    def read_chapter(chapter_element)
      result = ""
      path = chapter_element.child.attributes["href"].value
      return result unless path

      chapter_page = Nokogiri::HTML(open(chapter_url(path)))

      chapter_title = chapter_page.css(".parttop").children.first.child.text
      
      result << "<br /><p>#{chapter_title}</p><br />"
      chapter_contents = chapter_page.css("#bookpartinfo").children

      chapter_contents[1..-2].each do |element|
        result << element.to_s
      end

      result << NEWLINE
    end

    def create_builder(book_id, tmpdir, chapter_list)
      title_page = Nokogiri::HTML(open(title_url(book_id)))

      parsed_identifier = title_url(book_id)
      parsed_title = title_page.css(".bookname").text
      metadata = title_page.css("#bookul li")
      parsed_author = metadata.first.children.last.text[1..-2]
      parsed_date = metadata[3].children.last.text.split(":")[1..-1].join(":")

      image_path = download_image(title_page.css(".bookimg"), tmpdir)

      builder = GEPUB::Builder.new do
        unique_identifier parsed_identifier, 'url'
        language 'zh'

        title parsed_title
        creator parsed_author

        id book_id

        date parsed_date
        publisher "shushuw.cn"

        resources(:workdir => tmpdir) do
          cover_image image_path
          ordered do
            chapter_list.each do |chapter_info|
              file chapter_info[:file]
              heading chapter_info[:title]
            end
          end
        end

        # category (the thing in /list-7.html's a tag)
        # summary: the last li

        # www.shushuw.cn/search/authorname/0.html
      end

      builder
    end
  end

  private

  class << self
    def table_of_contents_url(book_id)
      SHUSHUWEN_URL + "/booklist/#{book_id}.html"
    end

    def chapter_url(chapter_path)
      SHUSHUWEN_URL + chapter_path
    end

    def title_url(book_id)
      SHUSHUWEN_URL + "/shu/#{book_id}.html"
    end

    def chapter_id(chapter)
      path = chapter.children.first.attributes["href"].value
      path.split("/").last.gsub(".html", "")
    end

    def chapter_title(chapter)
      chapter.children.first.text
    end

    def download_image(image_element, tmpdir)
      url = SHUSHUWEN_URL + image_element.first.attributes["src"].value
      filename = url.split("/").last
      file_path = File.join(tmpdir, filename)
      File.open(file_path, "wb") do |file|
        file.write(open(url).read)
      end
      filename
    end

    # Appends the chapter text to the file.
    def output_to_file(text, output_file_name)
      if output_file_name
        output_file = File.open(output_file_name, "a")
        output_file.write(text)
        output_file.close
      else
        p text
      end
    end

    def debug_mode?
      DEBUG_MODE
    end

    def debug(text)
      p text if debug_mode?
    end
  end
end
