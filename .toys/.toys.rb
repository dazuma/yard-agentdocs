# frozen_string_literal: true

expand :clean do |t|
  t.paths = :gitignore
  t.preserve = [".claude/plans", ".claude/settings.local.json"]
end

expand :minitest, libs: ["lib", "test"], bundler: true

expand :rubocop, bundler: true

expand :yardoc do |t|
  t.generate_output_flag = true
  t.fail_on_warning = true
  t.fail_on_undocumented_objects = true
  t.bundler = true
end

expand :gem_build

expand :gem_build, name: "install", install_gem: true

# Dogfooding: make the tools this gem ships (which users get via
# `load_gem "yard-agentdocs"`) available in this repo too. `load_gem` would
# activate the gem and so put its `lib` on the load path; loading straight off
# disk doesn't, so do it by hand.
$LOAD_PATH.unshift(::File.expand_path("../lib", __dir__))
load(::File.expand_path("../toys", __dir__))
