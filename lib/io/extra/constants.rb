require 'rbconfig'

module Extra
  module Constants
    # IOV_MAX is used by the write method.
    case RbConfig::CONFIG['host_os']
      when /sunos|solaris/i
        IOV_MAX = 16
      else
        IOV_MAX = 1024
    end

    # Various internal constants

    DIRECTIO_OFF = 0        # Turn off directio
    DIRECTIO_ON  = 1        # Turn on directio
    DIRECT       = 00040000 # Direct disk access hint
  end
end
