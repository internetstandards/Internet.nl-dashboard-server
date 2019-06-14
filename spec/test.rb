# Basics should work
describe http('https://172.30.1.5',  ssl_verify: false, max_redirects: 3) do
  its('status') { should eq 200 }
  its('body') { should match 'Login' }
end

# Press F to pay respect
describe http('https://172.30.1.5',  ssl_verify: false, max_redirects: 3) do
  its('status') { should eq 200 }
  its('headers.x-clacks-overhead') { should match 'GNU Terry Pratchet' }
end
