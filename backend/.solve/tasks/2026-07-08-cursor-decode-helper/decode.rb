require 'base64'
require 'json'

def decode(cursor)
  padded = cursor.tr('-_', '+/').ljust((cursor.length + 3) & ~3, '=')
  JSON.parse(Base64.decode64(padded))
end
