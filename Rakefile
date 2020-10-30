require "bundler/gem_tasks"

task default: %I{test:unit test:functional}

# Code Style Tasks
require "chefstyle"
require "rubocop/rake_task"
RuboCop::RakeTask.new(:lint) do |task|
  task.options << "--display-cop-names"
end

# Markdown Lint
namespace :lint do
  desc 'Linting for all markdown files'
  task :markdown do
    require 'mdl'

    MarkdownLint.run(%w[--verbose README.md CHANGELOG.md])
  end
end

# Version Bumping
require 'bump/tasks'
%w[set pre file current].each { |task| Rake::Task["bump:#{task}"].clear }
Bump.changelog = :editor
Bump.tag_by_default = true
