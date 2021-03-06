require 'beaker-rspec'
require 'pry'
require 'securerandom'

files_dir = ENV['files_dir'] || '/home/jenkins/puppet'

proxy_host = ENV['proxy_host'] || ''

gem_proxy = ''
gem_proxy = "http_proxy=http://#{proxy_host}" unless proxy_host.empty?

hosts.each do |host|
  # Install Puppet
  if host.is_pe?
    install_pe
  else
    puppetversion = ENV['VM_PUPPET_VERSION']
    install_package host, 'rubygems'
    on host, "#{gem_proxy} gem install puppet --no-ri --no-rdoc --version '~> #{puppetversion}'"
    on host, "mkdir -p #{host['distmoduledir']}"

    if fact('osfamily') == 'Suse'
      install_package host, 'ruby-devel augeas-devel libxml2-devel'
      on host, "#{gem_proxy} gem install ruby-augeas --no-ri --no-rdoc"
    end

  end

  # Setup proxy if its enabled
  if fact('osfamily') == 'Debian'
	  on host, "echo 'Acquire::http::Proxy \"http://#{proxy_host}/\";' >> /etc/apt/apt.conf.d/10proxy" unless proxy_host.empty?
  end
  if fact('osfamily') == 'RedHat'
    on host, "echo 'proxy=http://#{proxy_host}/' >> /etc/yum.conf" unless proxy_host.empty?
  end

  # Copy over some files
  if fact('osfamily') == 'Debian'
    scp_to(host, "#{files_dir}/elasticsearch-1.1.0.deb", '/tmp/elasticsearch-1.1.0.deb')
  end

  if fact('osfamily') == 'RedHat'
    scp_to(host, "#{files_dir}/elasticsearch-1.1.0.noarch.rpm", '/tmp/elasticsearch-1.1.0.noarch.rpm')
  end

end

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # Install module and dependencies
    puppet_module_install(:source => proj_root, :module_name => 'elasticsearch')
    hosts.each do |host|

      if !host.is_pe?
        scp_to(host, "#{files_dir}/puppetlabs-stdlib-3.2.0.tar.gz", '/tmp/puppetlabs-stdlib-3.2.0.tar.gz')
        on host, puppet('module','install','/tmp/puppetlabs-stdlib-3.2.0.tar.gz'), { :acceptable_exit_codes => [0,1] }
      end
      if fact('osfamily') == 'Debian'
        scp_to(host, "#{files_dir}/puppetlabs-apt-1.4.2.tar.gz", '/tmp/puppetlabs-apt-1.4.2.tar.gz')
        on host, puppet('module','install','/tmp/puppetlabs-apt-1.4.2.tar.gz'), { :acceptable_exit_codes => [0,1] }
      end
      if fact('osfamily') == 'Suse'
        on host, puppet('module','install','darin-zypprepo'), { :acceptable_exit_codes => [0,1] }
      end

    end
  end
end
