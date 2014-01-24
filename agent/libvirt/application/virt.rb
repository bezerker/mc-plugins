class MCollective::Application::Virt<MCollective::Application
    description "MCollective Libvirt Manager"

    usage "Usage: mco virt info"
    usage "Usage: mco virt info <domain>"
    usage "Usage: mco virt xml <domain>"
    usage "Usage: mco virt find <pattern>"
    usage "Usage: mco virt [stop|start|reboot|suspend|resume|destroy] <domain>"
    usage "Usage: mco virt domains"
    usage "Usage: mco virt define <domain> <local or remote xml file> [permanent]"
    usage "Usage: mco virt undefine <domain> [destroy]"

    option :connect,
        :description => "hypervisor connection URI",
        :arguments   => ["--connect"],
        :type        => :string,
        :optional    => true

    def post_option_parser(configuration)
        configuration[:command] = ARGV.shift if ARGV.size > 0
        configuration[:domain] = ARGV.shift if ARGV.size > 0

        if configuration[:domain] =~ /^\w+:\/\/[\S]+$/
            configuration[:connect] = configuration.delete(:domain)
        end
        puts configuration.inspect
    end

    def validate_configuration(configuration)
        raise "Please specify a command, see --help for details" unless configuration[:command]

        if ["xml", "stop", "start", "suspend", "resume", "destroy", "find"].include?(configuration[:command])
            raise "%s requires a domain name, see --help for details" % [configuration[:command]] unless configuration[:domain]
        end
    end

    def base_args
       base = Hash.new
       base[:libvirt_url] = configuration[:connect] if configuration[:connect] =~ /^\w:\/\/[\S]+$/
       base
    end

    def undefine_command
        configuration[:destroy] = ARGV.shift if ARGV.size > 0

        args = base_args.merge({:domain => configuration[:domain]})
        args[:destroy] = true if configuration[:destroy] =~ /^dest/

        printrpc virtclient.undefinedomain(args)
    end

    def define_command
        configuration[:xmlfile] = ARGV.shift if ARGV.size > 0
        configuration[:perm] = ARGV.shift if ARGV.size > 0

        raise "Need a XML file to define an instance" unless configuration[:xmlfile]

        args = base_args
        if File.exist?(configuration[:xmlfile])
            args[:xml] = File.read(configuration[:xmlfile])
        else
            args[:xmlfile] = configuration[:xmlfile]
        end

        args[:permanent] = true if configuration[:perm].to_s =~ /^perm/
        args[:domain] = configuration[:domain]

        printrpc virtclient.definedomain(args)
    end

    def info_command
        if configuration[:domain]
            printrpc virtclient.domaininfo(base_args.merge(:domain => configuration[:domain]))
        else
            printrpc virtclient.hvinfo(base_args)
        end
    end

    def xml_command
        printrpc virtclient.domainxml(base_args.merge(:domain => configuration[:domain]))
    end

    def domains_command
        virtclient.hvinfo(base_args).each do |r|
            if r[:statuscode] == 0
                domains = r[:data][:active_domains] << r[:data][:inactive_domains]

                puts "%30s:    %s" % [r[:sender], domains.flatten.sort.join(", ")]
            else
                puts "%30s:    %s" % [r[:sender], r[:statusmsg]]
            end
        end

        puts
    end

    def reboot_command
        printrpc virtclient.reboot(base_args.merge(:domain => configuration[:domain]))
    end

    def start_command
        printrpc virtclient.create(base_args.merge(:domain => configuration[:domain]))
    end

    def stop_command
        printrpc virtclient.shutdown(base_args.merge(:domain => configuration[:domain]))
    end

    def suspend_command
        printrpc virtclient.suspend(base_args.merge(:domain => configuration[:domain]))
    end

    def resume_command
        printrpc virtclient.resume(base_args.merge(:domain => configuration[:domain]))
    end

    def destroy_command
        printrpc virtclient.destroy(base_args.merge(:domain => configuration[:domain]))
    end

    def find_command
        pattern = Regexp.new(configuration[:domain])

        virtclient.hvinfo(base_args).each do |r|
            if r[:statuscode] == 0
                domains = r[:data][:active_domains] << r[:data][:inactive_domains]
                matched = domains.flatten.grep pattern

                if matched.size > 0
                    puts "%30s:    %s" % [r[:sender], matched.sort.join(", ")]
                end
            else
                puts "%30s:    %s" % [r[:sender], r[:statusmsg]]
            end
        end

        puts
    end

    def virtclient
        @client ||= rpcclient("libvirt")
    end

    def main
        cmd = configuration[:command] + "_command"

        if respond_to?(cmd)
            send(cmd)
        else
            raise "Support for #{configuration[:command]} has not yet been implimented"
        end
    end
end
