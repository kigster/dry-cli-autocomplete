# frozen_string_literal: true

module MyCLI
  module CLI
    module Commands
      # Scans a network, the local /24 unless --cidr names another, for hosts
      # that answer on TCP ports. This class reads the options and reports
      # the outcome; {Subnet}, {Scanner} and {PortProbe} do the probing, and
      # {ProgressDisplay} or {SpinnerDisplay} shows it.
      class FindHosts < ConcurrentCommand
        desc "Find hosts on the local network that listen on common TCP ports"

        option :ports, type: :array, desc: "Probe only these TCP ports, comma-separated, instead of the common ones"
        option :cidr, desc: "Scan this network instead of the local /24, such as 192.168.0.0/24"
        option :unlimited, aliases: ["-u"], type: :flag, default: false,
                           desc: "Scan a network of any size; without it, more than #{Subnet::SOFT_MAX_IPS} addresses is an error"
        option :timeout, aliases: ["-t"], type: :float, default: 0.5, desc: "Seconds to wait for each port"
        option :output, aliases: ["-o"], desc: "Also write the hosts to this file"
        option :list, type: :flag, default: false, desc: "Print the common ports and what listens on them, then exit"

        example [
          "",
          "--ports 22 --output hosts.txt",
          "--spinner --concurrency 20 --timeout 0.2",
          "--cidr 172.16.0.0/30 --ports 22,80,443",
          "--cidr 172.16.0.0/23 --cpus 12",
          "--list"
        ]

        # @param timeout [String, Float] seconds to wait for each port
        # @param ports [Array<String>, nil] the ports to probe, instead of the common ones
        # @param cidr [String, nil] the network to scan, instead of the local one
        # @param unlimited [Boolean] scan a network of any size
        # @param output [String, nil] a file to write the hosts to
        # @param list [Boolean] print the common ports instead of scanning
        # @param spinner [Boolean] show spinners instead of progress bars
        # @param options [Hash] :concurrency
        # @return [void]
        # @raise [SystemExit] with status 1, after reporting an error
        def call(timeout:, ports: nil, cidr: nil, unlimited: false, output: nil, list: false, spinner: false, **options)
          return list_ports if list

          count = concurrency(options[:concurrency])
          subnet = subnet(cidr, unlimited)
          scanner = Scanner.new(ports: port_numbers(ports), timeout: Float(timeout))
          FileLimit.allow(count * scanner.ports.size)

          ui.info "#{subnet.ip ? "Local IP: #{subnet.ip}, scanning" : 'Scanning'} #{subnet} on #{ports_phrase(scanner.ports)}"
          report = scan(subnet, scanner, display(spinner), count)
          File.write(output, report.text) if output && report.found?
          announce(report, scanner, output)
        end

        private

        # @return [void]
        def list_ports
          Scanner::SERVICES.each { |port, service| stdout.puts "#{port.to_s.rjust(5)}  #{service}" }
        end

        # @param cidr [String, nil]
        # @param unlimited [Boolean]
        # @return [Subnet] the network to scan
        def subnet(cidr, unlimited)
          subnet = cidr ? Subnet.from_cidr(cidr) : Subnet.local
          error!("No local IPv4 address found", "Name a network with --cidr") unless subnet
          subnet.within!(unlimited ? nil : Subnet::SOFT_MAX_IPS)
        rescue IPAddr::InvalidAddressError
          error!("--cidr #{cidr} is not a network", "Give one such as 192.168.0.0/24")
        rescue WillNotScanNetworkThisLargeError => e
          error!(e.message, "Pass --unlimited to scan it anyway")
        end

        # @param ports [Array<String>, nil]
        # @return [Array<Integer>] the ports given, or the common ones without any
        def port_numbers(ports)
          return Scanner::COMMON_PORTS if ports.nil? || ports.empty?

          numbers = ports.map { |port| Integer(port, 10, exception: false) }
          return numbers if numbers.all? { |number| number&.between?(1, 65_535) }

          error!("--ports takes port numbers from 1 to 65535, such as 22,80", "Got #{ports.join(',')}")
        end

        # Ctrl-C lets the addresses being probed finish, and probes no more.
        #
        # @return [Report]
        def scan(subnet, scanner, display, concurrency)
          ui.stoppable do |stop|
            results = display.new(ui:, scanner:, concurrency:, stop:).call(subnet.addresses)
            Report.new(addresses: subnet.addresses, results:, stopped: stop.stopped?)
          end
        end

        # @return [void]
        def announce(report, scanner, output)
          if report.stopped
            ui.info "Stopped", "Scanned #{scanner.scanned} of #{report.addresses.size} addresses, " \
                               "and found #{report.hosts.size} hosts", *report.lines
          elsif !report.found?
            ui.warn "No hosts answered on #{scanner.ports.join(', ')}"
          else
            ui.success "Found #{report.hosts.size} hosts", report.text.chomp, *("Written to #{output}" if output)
          end
        end

        # @return [String] such as "port 22" or "ports 22, 80"
        def ports_phrase(ports) = "#{ports.one? ? 'port' : 'ports'} #{ports.join(', ')}"
      end
    end
  end
end
