#!/usr/bin/env ruby

$: << "../lib"

require 'shushuwhee'
require 'shushuwhee/cmd_parser'

PROGNAME = File.basename(__FILE__)
BANNER = "
  Synopsis:
    #{PROGNAME} [options] <cmd> [-- <cmd options>] [argv1, argv2, ...]

  This script downloads a book from given url.
"

CMDS = [ ['get', 'get something', false],
         ['set', 'set something', false],
       ]

EXAMPLES = "
  Description:
    This is a brief description

  Examples:
    Some sample cmds

	#{PROGNAME}  [ --debug] [ --dir ./shu ]  --file book.list get 
	#{PROGNAME}   get  1234 5678 56789
"

CMD_SPECS = \
  {:banner => BANNER,
   :commands => CMDS,
   :specs  => [
               ['debug', nil, false, nil, false, "optional boolean option with default value of false"],
               ['dir', 'd', "dir=./shu", String, false, "destination dir for downloaded files"],
               ['file', 'f', "file", String, false, "a file contains list of books to download"],
   ],
   :examples => EXAMPLES
  }

### end of CLI options definitions #####

class CmdRunner
  KNOWN_CMDS = ['get', 'set', 'do']

  def initialize(parser)
    @cmd_parser = parser
    begin
      @cmd_parser.parse
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      puts e.to_s
      puts "use --help option to see usage message"
      exit 1
    end
    @opts        = @cmd_parser.options
    @subcmd_opts = @cmd_parser.additional_opts
    @subcmd_argv = @cmd_parser.subcmd_argv
    puts "opts: #{@opts}\n\n" if @opts[:debug]
  end

  def run(cmd = @opts[:cmd])
    if KNOWN_CMDS.include?(cmd)
      send("do_#{cmd}", @opts, @subcmd_argv) 
    else  
      do_default(cmd, @subcmd_opts, @subcmd_argv)
    end
  end

  def do_get(opts={}, argv=[])
    if opts[:debug]
      puts "Execute cmd 'get':"
      puts "  do_get(): opts = #{opts}; argv = #{argv}"
    end
    if opts[:file]
      File.open(opts[:file]) do | file | 
        books = file.readlines
        Shushuwhee.read_many(books, opts[:dir])
        
#        while line = file.gets
#          puts "downloading book: #{line}"
#        end
      end
    else
      @subcmd_argv.each do | book_id |
        puts "downloading book: #{book_id}"
        Shushuwhee.read_book(book_id, book_id)
      end
    end
  end

#  def do_set(opts={}, argv=[])
#    puts "Execute cmd 'set':"
#    puts "  do_set(): opts = #{opts}; argv = #{argv}"
#  end
#
#  def do_default(cmd, opts={}, argv=[])
#    if cmd.nil?
#      puts @cmd_parser.optparse 
#      raise
#    end
#    puts "Execute cmd 'default':"
#    puts "  do_default(): cmd  = '#{cmd}'"
#    puts "                opts = '#{opts}'"
#    puts "                argv = '#{argv}'"
#  end

end

@cmd_parser = Shushuwhee::CmdParser.new(CMD_SPECS)

begin
  runner = CmdRunner.new(@cmd_parser)
  runner.run
  @rc = 0
rescue => e
  $stderr.puts "#{e.to_s}\n%s" % e.backtrace
  @rc = 1
end

exit @rc
