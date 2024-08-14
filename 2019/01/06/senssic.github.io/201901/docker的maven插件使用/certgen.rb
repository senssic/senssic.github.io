# Generates necessary certificates to ~/.docker
#
# Usage:
#   bundle install
#   ruby certgen.rb <domain>

require 'certificate_authority'
require 'fileutils'

if ARGV.empty?
  puts "Usage: ruby certgen.rb <domain>"
  exit 1
end

$domain = ARGV[0]

$certs_path = File.join(ENV['HOME'], '.docker')

def certificate_authority
  cert_path = File.join($certs_path, 'ca', 'cert.pem')
  ca_path = File.join($certs_path, 'ca', 'key.pem')

  key_material = if File.exist?(ca_path)
    key = OpenSSL::PKey::RSA.new(File.read(ca_path))
    mem_key = CertificateAuthority::MemoryKeyMaterial.new
    mem_key.public_key = key.public_key
    mem_key.private_key = key
    mem_key
  else
    mem_key = CertificateAuthority::MemoryKeyMaterial.new
    mem_key.generate_key
    mem_key
  end

  if File.exist?(cert_path)
    raw_cert = File.read(cert_path)
    openssl = OpenSSL::X509::Certificate.new(raw_cert)
    cert = CertificateAuthority::Certificate.from_openssl(openssl)
    cert.key_material = key_material
    cert
  else
    root = CertificateAuthority::Certificate.new
    root.subject.common_name = $domain
    root.serial_number.number = 1
    root.signing_entity = true
    root.key_material = key_material

    ca_profile = {
      "extensions" => {
        "keyUsage" => {
          "usage" => [ "critical", "keyCertSign" ]
        }
      }
    }

    root.sign!(ca_profile)

    root
  end
end

def server_certificate(root)
  server = CertificateAuthority::Certificate.new
  server.subject.common_name = $domain
  server.serial_number.number = rand(3..100000)
  server.parent = root
  server.key_material.generate_key
  server.sign!
  server
end

def client_certificate(root)
  client = CertificateAuthority::Certificate.new
  client.subject.common_name = $domain
  client.serial_number.number = 2
  client.parent = root

  client.key_material.generate_key

  signing_profile = {
    "extensions" => {
      "extendedKeyUsage" => {
        "usage" => [ "clientAuth" ]
      }
    }
  }

  client.sign!(signing_profile)

  client
end

root = certificate_authority
server = server_certificate(root)
client = client_certificate(root)

[
  # You can reuse this file to generate more certs
  ['ca/key.pem', root.key_material.private_key],
  ['ca/cert.pem', root.to_pem],

  # Those are default filenames expected by Docker
  ['ca.pem', root.to_pem],
  ['key.pem', client.key_material.private_key],
  ['cert.pem', client.to_pem],

  # Those files are supposed to be uploaded to server
  ["#{$domain}/ca.pem", root.to_pem],
  ["#{$domain}/key.pem", server.key_material.private_key],
  ["#{$domain}/cert.pem", server.to_pem]
].each do |name, contents|
  path = File.join($certs_path, name)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, contents)
  File.chmod(0600, path)
end

puts "CA certificates are in #{$certs_path}/ca"
puts "Client certificates are in #{$certs_path}"
puts "Server certificates are in #{$certs_path}/#{$domain}"
