
require 'rubygems'
require 'optparse'

# monkey patching, adding a boolean? method to all Objects
class Object
  def boolean?
    self.is_a?(TrueClass) || self.is_a?(FalseClass)
  end
end

module Shushuwhee
  
  # define exceptions
  class CmdError < StandardError; end
  class CmdDefinitionError < StandardError; end
  class ConfigureError < StandardError; end
  class ManifestError < StandardError; end
  class UnSupportedApplication < StandardError; end

#  Arguments:
#  cmd_specs: a hash contains following items:
#    :banner  the banner message 
#    :commands an array of arrays. Each item (an array represents a defined sub command:
#             [cmd_name, cmd_desc, default_cmd], can be an empty array [], see not below.
#         cmd_name:   sub_cmd name
#         cmd_desc:   a string description of this sub cmd
#         default_cmd a boolean value, true | false, if true, this is default sub cmd to run
#                     when a sub_cmd is not provided on CLI
#
#      note: if cmd array is empty, we allow any sub cmd to be giving on CLI, disabling 
#            validation on sub cmds. This allows us to dynamically adding new sub cmds.
#              
#    :spec    array of arrays. Each item (an array) represents one command line option, 
#             [opt_name, short, opt_arg, opt_type, required, message]
#         opt_name:   option name, which becomes "--opt_name" long option,                
#         short:      one single letter, which becomes "-x" short option,
#         opt_arg:    if its value is "true" or "false", then this option is a boolean
#                     and its default value is opt_arg,
#                     if its value is a string, then it becomesarg for "--opt_name opt_arg",
#                     if its value is in form of "name=val", then val is default value for
#                     this option.
#         opt_type:   object type for the option, eg: Integer, String.
#         required:   if it is true, this option is mandatory.
#         message:    usage message for this option.
#    :examples  a multi line text block, for additional desriptions, comments, usage exampels.
#
#  Returns:
#     returns an options hash where keys are :opt_name, and values are cmd line options or 
#     their default values.
#
#  Example: giving following cmd_spec :
#      specs = {:banner => "Usage: #{File.basename(__FILE__)} [Options]",
#               :commands => [['list', 'list something', false]],
#               :specs  => [
#                 ['delay', 'd', "seconds=5", Integer, false,  "delay in seconds"],
#                 ['log', 'l', "file=/var/log/my.log", String, false,  "log filename"],
#                 ['verbose', 'v', false, nil,  false, "for verbose output"]
#                 ]}
#  will generate this options hash:
#    options = {:delay => 5, :log => "/var/log/my.log", :verbose => false}
#
#  Usage:
#          cmd_parser = Mmc::CmdParser.new(cmd_specs)
#          options = cmd_parser.parse
#
  class CmdParser
    attr_reader :additional_opts, :args, :optparse, :options, :subcmd_argv, :defined_cmds
 
    def initialize(cmd_specs)
      @cmd_specs = cmd_specs
      @allow_dynamic_subcmds = false
      @args = []
      @options = {}
      @subcmd_argv = []
      @option_list = []
      @mandatory = []
      @additional_opts = {}  # these are arguments after "--" separator
      @defined_cmds = @cmd_specs[:commands].collect { |item| item[0] } if @cmd_specs[:commands]
    end
  
    def parse(args=ARGV)
      @optparse = OptionParser.new do |opt|
        opt.banner = @cmd_specs[:banner]

        # commands section
        if @cmd_specs[:commands]
          opt.separator ''
          opt.separator '  Commands:'
          @cmd_specs[:commands].each do | spec |
            if spec.empty?
              @allow_dynamic_subcmds = true
              break
            end
            raise Mmc::CmdDefinitionError, "missing fields in spec '#{spec}'" if spec.size != 3
            cmd, msg, default = spec
            opt.separator "    %-16s  %s" % [cmd, msg]
            @options[:cmd] = cmd if default
          end 
        end 
        # print out default command
        if @options[:cmd]
          opt.separator  ''  
          opt.separator "    %-16s  is the default command." % @options[:cmd]
          opt.separator  ''  
        end 

        # Options section
        if @cmd_specs[:specs]
          opt.separator  ''  
          opt.separator  '  Options'
          @cmd_specs[:specs].each do |spec|
            arr = []
            raise Mmc::CmdDefinitionError, "missing fields in spec '#{spec}'" if spec.size != 6
            optname, short, optarg, opt_type, required, msg = spec
            raise Mmc::CmdDefinitionError, "long and short option names can not both be nil" if optname.nil? and short.nil?
            optname = short if optname.nil?
            @option_list << optname.to_sym if optarg =~ /=/ || optarg.boolean?
            @mandatory << optname.to_sym if required
            arr << '-%s' % short unless short.nil?
            optarg.boolean? ? arr << '--%s' % optname : arr << '--%s %s' % [optname, optarg.split('=')[0]]
            arr << opt_type unless opt_type.nil?
            arr << msg
    
            # set default option values
            @options[optname.to_sym] = optarg if optarg.boolean?
            if optarg =~ /=/
              opt_type == Integer ? default = optarg.split('=')[1].to_i : default = optarg.split('=')[1]
              @options[optname.to_sym] = default
            end
  
            opt.on(*arr) do |o|
              if optarg.boolean?
                @options[optname.to_sym] = !@options[optname.to_sym]
              else
                raise OptionParser::MissingArgument, "option requires a string value" if o.instance_of?(String) and o.start_with?("-")
                optarg.nil? ? nil : @options[optname.to_sym] = o
              end
            end
          end
        end

        # print out options' default values
        unless @option_list.empty?
          opt.separator ''
          opt.separator '  Default option values:'
          @option_list.sort.each do |o|
            opt.separator "    --%s=%s" % [o.to_s, @options[o]]
          end
        end 

        # additional usage comments and usage examples
        opt.separator @cmd_specs[:examples]
      end  # end of @optparse block

      @optparse.parse!(args)
      # check for existence of mandatory options
      @mandatory.each do |m|
        raise OptionParser::MissingArgument, "option --#{m} is mandatory." unless @options.keys.include?(m)
      end

      # parse remaining args array, assign first arg as subcmd
      unless args.empty? 
        @options[:cmd] = args.shift unless @cmd_specs[:commands].nil?
        @options = @options.merge(handle_arbitrary_options(args))
      end
      @options[:argv] = args

      # verify found subcmd is among defined subcmd
      if @cmd_specs[:commands] and @allow_dynamic_subcmds == false
        @defined_cmds = @cmd_specs[:commands].collect { |item| item[0] }
        if ( @options[:cmd] and not @defined_cmds.include?(@options[:cmd]) )
          raise OptionParser::InvalidOption, "subcmd '#{@options[:cmd]}' is not among defined cmds '#{@defined_cmds}'"
        end
      end

      return @options
    end  # end of parse method

    # additional args after "--" are converted to a hash, if any of its items 
    # starts with '-' or '--'. 
    # examples:
    #   -s                       => {:s => nil}
    #   -sval                    => {:s => val}       <<<=== NOT SUPPORTED YET
    #   -s val                   => {:s => val}
    #   --this=val or --this val => {:this => 'val'}
    #
    def handle_arbitrary_options(args_array)
      i = 0
      @subcmd_argv = []
      size = args_array.size
      while i < size
        if args_array[i] =~ /^-|^--/
          item = args_array[i].gsub('-', '')
          if item =~ /=/
            key, val = item.split('=')
            val = casting_to_default_types(val)
          else
            key = item
            val = casting_to_default_types(args_array[i+1])
            i += 1 unless ( args_array[i+1].nil? or args_array[i+1].start_with?("-") )
          end
          @additional_opts[key.to_sym] = val
        else 
          @subcmd_argv << args_array[i] unless args_array[i].nil?
        end
        i += 1
      end
      @additional_opts
    end # handle_arbitrary_options method

    # TODO: handle floating numbers 
    def casting_to_default_types(s)
      return true if s.nil?          # nothing following last option 

      case s
      when /^-\D+$|^--/              # next option name
        val = true
      when /^-?\d+$/                 # positive and negative integers
        val = s.to_i 
      when /^[Tt][Rr][Uu][Ee]$/      # 'true' in any combination of cases
        val = true
      when /^[Ff][Aa][Ll][Ss][Ee]$/  # 'false' in any combination of cases
        val = false 
      else
        val = s                      # non of above
      end
      val
    end

  end  # CmdParser class

end  # Mmc module
