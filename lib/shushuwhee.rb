require "shushuwhee/version"
require 'open-uri'
require 'nokogiri'

module Shushuwhee
  SHUSHUWEN_URL = "http://www.shushuw.cn/"

  class << self
    # Finds all the books in book_list and reads them, outputting their
    # content as text files in the "shu" folder (creates folder if missing).
    def read_many(book_list, output_folder_name="shu")
    end

    # Shushuwhee.read(book_id)
    # @param output_file_name The file to output the parsed story as.
    #   If nil, outputs to stdout. 
    def read_book(book_id, output_file_name=nil)
      table_of_contents = Nokogiri::HTML(open(table_of_contents_url(book_id)))
      chapters = table_of_contents.css("li")

      chapters.each do |chapter|
        chapter_text = read_chapter(chapter)

      end
    end

    # Returns the chapter text for a given chapter
    def read_chapter(chapter_xml_element)
    end
  end

  # Your code goes here...
  private

  class << self
    def table_of_contents_url(book_id)
      SHUSHUWEN_URL + "/booklist/#{book_id}.html"
    end
  end
end
