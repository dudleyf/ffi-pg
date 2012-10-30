require "bundler/gem_tasks"
require "git"
require "logger"

file 'vendor/ruby-pg' => :clone_ruby_pg

task :clone_ruby_pg do |t|
  repo = "git://github.com/jvshahid/ruby-pg.git"
  Git.clone repo, t.name, :log => Logger.new(STDOUT)
end

task :update_ruby_pg do
  git = Git.open '/vendor/ruby-pg', :log => Logger.new(STDOUT)
  git.pull
end

task :spec do
  system "bundle exec rspec spec"
end