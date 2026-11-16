# @summary Installs the ovlens package
#
# @api private
class ovlens::install {
  assert_private()

  if $ovlens::package_manage {
    if $ovlens::package_source {
      # A package file. The dependency-resolving providers cannot take one, so
      # the low-level provider for the OS family is used instead. That is safe
      # here because the package's only dependency is openvox-agent, which a
      # node running this already has.
      $provider = $ovlens::package_provider ? {
        undef   => $facts['os']['family'] ? {
          'Debian' => 'dpkg',
          default  => 'rpm',
        },
        default => $ovlens::package_provider,
      }

      # dpkg cannot pin a version. The file is the version anyway, but say so
      # rather than install whatever it holds while a pin is believed to apply.
      $unversionable = ['present', 'installed', 'absent', 'purged']
      if $provider == 'dpkg' and !($ovlens::package_ensure in $unversionable) {
        fail("ovlens::package_ensure must be one of ${unversionable.join(', ')} when installing from ovlens::package_source with dpkg, which cannot pin a version")
      }

      package { $ovlens::package_name:
        ensure   => $ovlens::package_ensure,
        source   => $ovlens::package_source,
        provider => $provider,
      }
    } else {
      package { $ovlens::package_name:
        ensure => $ovlens::package_ensure,
      }

      # Whichever module configures the harpworks repository, this one or
      # codavox, it has to be in place before the package is looked up.
      Yumrepo <| title == 'harpworks' |> -> Package[$ovlens::package_name]
      Exec <| title == 'harpworks apt-get update' |> -> Package[$ovlens::package_name]
    }
  }
}
