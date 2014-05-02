# encoding: utf-8

require 'bundler'
Bundler.setup :default

require 'blur'

def random_nickname
  suffix = rand(100_000_000).to_s 36

  "blur-contrib#{suffix}"
end

options = {
  networks: [
    {
      hostname: "irc.uplink.io",
      nickname: "blur-contrib#{rand(100_000_000).to_s 36}",
      channels: %w{#blur-contrib},
      secure: true
    }
  ]
}

Blur.connect options do
  # …
end
