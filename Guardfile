# A sample Guardfile
# More info at https://github.com/guard/guard#readme

notification :growl

guard 'rspec' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/mongo_versionable/(.+)\.rb$}) do |m|
    ["spec/unit/#{m[1]}_spec.rb", "spec/integration/#{m[1]}_spec.rb"]
  end
  watch('spec/spec_helper.rb')  { "spec" }
end

# END
