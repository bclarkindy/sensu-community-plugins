# Sensu Community Plugins
**Upstream master:** [![Build Status](https://travis-ci.org/sensu/sensu-community-plugins.png?branch=master)](https://travis-ci.org/sensu/sensu-community-plugins)

**Branch bcmaster:** [![Build Status](https://travis-ci.org/bclarkindy/sensu-community-plugins.png?branch=bcmaster)](https://travis-ci.org/bclarkindy/sensu-community-plugins)

## Community plugins, extensions, and handlers

This gem contains some example plugins and handlers for Sensu. Most of
them are implemented in Ruby and use the `sensu-plugin` framework (a
small gem); some also depend on additional gems (e.g. `mysql`). Some
are shell scripts! All languages are welcome.

In the future, some sort of browsing/metadata/installation system may be
implemented. For now, just clone this repository, take a look around,
and copy the plugins you want to use.

## Contributing

If you have a new plugin or handler, send a pull request! Please format
the names of scripts using dashes to separate words and with an
extension (`.rb`, `.sh`, etc), and make sure they are `chmod +x`'d.
Extensions are unfortunately necessary for Sensu to be able to directly
exec plugins and handlers on Windows.

Dependencies (ruby gems, packages, etc) and other requirements should
be declared in the header of the plugin/handler file.

Only pull requests passing lint/tests will be merged.

Please do not not abandon your pull request, only you can help us merge 
it. We will wait for feedback from you on your pull request for up to 
one month. A lack of feedback in one month may require you to re-open 
your pull request.

## Production usage

Because of the nature of this repository:

* no test coverage
* specific and exotic software being checked
* no versioning system for plugins 

this is not recommended that you use master for your production instances.
Better pick something which works for you and lock it via `:ref` in your
`chef || puppet || ansible || bash script` you name it. 

If you have installed Sensu using the omnibus package it will use an embedded
version of ruby, but the ruby plugins here will use the system one. If you want
to use the embedded ruby, which has the `sensu-plugin` gem installed as well,
you can set `EMBEDDED_RUBY=true` in `/etc/default/sensu` and restart the Sensu
services. This will put the embedded ruby first in the $PATH for commands run
by the Sensu services.

## Rubocop linting

Rubocop is used to lint the style of the ruby plugins. This is done
to standardize the style used within these plugins, and ensure high
quality code.  Feel free to submit changes to .rubocop.yml with
pull requests.


```
bundle install
bundle exec rubocop
```

## RSpec Testing

Currently we have RSpec as a test framework. Please add coverage for your check.
This is ~~little bit hard~~ almost impossible for non-ruby checks. But don't be afraid on pushing your PR with non-ruby code. Just let someone from [team](https://github.com/sensu?tab=members) know. Maybe we can help you to rewrite your check to Ruby or even we can invent something completely new to test your work. Just don't hesitate to contact us.


## License

Copyright 2011 Sonian, Inc. and contributors.

Released under the same terms as Sensu (the MIT license); see LICENSE
for details.

NOTE: When adding a plugin, copy the preceding two paragraphs to a
comment in each source file, changing the copyright holder to your own
name or organization. If you wish to use a different open source
license, please submit a pull request adding that license to the repo
and use that license's boilerplate instead.
