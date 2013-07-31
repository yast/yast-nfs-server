[
  { "allowed" => ["(rw)"], "mountpoint" => "/insane" },
  { "allowed" => ["(ro)"], "mountpoint" => "/continued/line" },
  { "allowed" => ["\\"], "mountpoint" => "/a/backslash/that/does/not/continue" },
  { "allowed" => ["foo(bar)"], "mountpoint" => "/ Balls" },
  { "allowed" => ["baz(noo)"], "mountpoint" => "/really/weird/quoting" },
  { "allowed" => ["foo(bar)"], "mountpoint" => "/or/ octal/stuff" },
  {
    "allowed"    => ["ignored", "that", "was", "a", "host", "too"],
    "mountpoint" => "/othe\\r/\\backslashes/\\\\are/\\"
  },
  { "allowed" => ["foo(bar)"], "mountpoint" => "/see/a/\t/tab/and/a/\"/quote" },
  { "allowed" => ["options(foo)", "another(qux)"], "mountpoint" => "/multiple" },
  { "allowed" => ["foo(bar)", "baz(kvuuks)"], "mountpoint" => "/split" },
  { "allowed" => [], "mountpoint" => "/what/about//a/lone/quote" },
  { "allowed" => ["of(tests)"], "mountpoint" => "/end" }
]
