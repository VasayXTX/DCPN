#coding: utf-8

class SysInfo
  def self.get_h_info
    f = IO.popen('ohai')
    info = f.readlines
    info = (info.each { |str| str.chomp! }).join('')
    h_info = JSON.parse(info)
    
    h_info
  end
  private_class_method :get_h_info

  def self.get_spec_linux h_info
    {
      'memory' => {
        'total' => h_info['memory']['total'],
        'free' => h_info['memory']['free']
      },
    }
  end
  private_class_method :get_spec_linux

  def self.get_spec_windows h_info
    {
      'memory' => {
        'total' => h_info['kernel']['cs_info']['total_physical_memory'],
        'free' => h_info['kernel']['os_info']['free_physical_memory']
      },
    }
  end
  private_class_method :get_spec_windows

  def self.get
    h_info = get_h_info

    res = if h_info['os'] == 'linux'
            get_spec_linux h_info
          else
            get_spec_windows h_info
          end

    res.merge!({
      'os' => {
        'name' => h_info['os'],
        'version' => h_info['os_version']
      },
      'user' => h_info['current_user'],
      'cpu' => h_info['cpu']
    })

    res
  end
end

