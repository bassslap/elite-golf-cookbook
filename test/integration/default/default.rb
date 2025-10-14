# InSpec test for Elite Golf login page accessibility and title check

if os.windows?
  control 'eg-port' do
    impact 0.6
    title 'Elite Golf Port is Listening'
    desc 'Operational Check - Is Elite Golf Listening'
    describe port(443) do
      it { should be_listening }
    end
    describe port(80) do
      it { should be_listening }
    end
    describe port(8880) do
      it { should be_listening }
    end
  end
else
  describe http('https://localhost/login.view', ssl_verify: false) do
    its('body') { should match(%r{<title>Elite Golf Club</title>}) }
    its('status') { should eq 200 }
  end
end