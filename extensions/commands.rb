# encoding: utf-8

Extension :commands do
  Author "Mikkel Kroman <mk@uplink.io>"
  Version "0.1"
  Description "Extends the script with the commands DSL framework."

  def extension_used script
    script.extend Blur::Script::Commands
  end
end
