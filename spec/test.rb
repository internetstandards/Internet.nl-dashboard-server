describe http('https://172.30.1.5',  ssl_verify: false, max_redirects: 3) do
  its('status') { should eq 200 }
  its('body') { should match 'Login' }
end