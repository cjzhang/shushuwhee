require "shushuwhee/version"
require 'open-uri'
require 'nokogiri'

module Shushuwhee
  SHUSHUWEN_URL = "http://www.shushuw.cn/"
  NEWLINE = "\r\n"

  class << self
    # Finds all the books in book_list and reads them, outputting their
    # content as text files in the "shu" folder (creates folder if missing).
    def read_many(book_list, output_folder_name="shu")
    end

    # Shushuwhee.read(book_id)
    # @param output_file_name The file to output the parsed story as.
    #   If nil, outputs to stdout. 
    def read_book(book_id, output_file_name=nil)
      puts "#{book_id}"
      output_file = nil
      if output_file_name
        output_file = File.open(output_file_name, "w")
      end

      table_of_contents = Nokogiri::HTML(open(table_of_contents_url(book_id)))
      chapters = table_of_contents.css("ul li")

      chapters.each do |chapter|
        chapter_text = read_chapter(chapter)
        output(chapter_text, output_file)
        printf "."
      end

      if output_file
        output_file.close
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
      
      result << NEWLINE + chapter_title + NEWLINE
      chapter_contents = chapter_page.css("#bookpartinfo").children

      chapter_contents[1..-2].each do |element|
        result << NEWLINE
        result << element.text.strip
        result << NEWLINE
      end

      result << NEWLINE
    end
  end

  # Your code goes here...
  private

  class << self
    def table_of_contents_url(book_id)
      SHUSHUWEN_URL + "/booklist/#{book_id}.html"
    end

    def chapter_url(chapter_path)
      SHUSHUWEN_URL + chapter_path
    end

    def output(text, output_file)
      if output_file
        output_file << text
      else
        p text
      end
    end
  end
end
