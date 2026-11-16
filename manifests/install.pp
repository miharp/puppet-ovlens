# @summary Installs the ovlens gem
#
# @api private
class ovlens::install {
  assert_private()

  if $ovlens::package_manage {
    package { $ovlens::package_name:
      ensure   => $ovlens::package_ensure,
      provider => $ovlens::package_provider,
      source   => $ovlens::package_source,
    }
  }
}
