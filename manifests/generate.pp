# @summary Regenerates the documentation from a systemd timer
#
# @api private
class ovlens::generate {
  assert_private()

  file { $ovlens::docs_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  $present = $ovlens::generate_ensure == 'present'
  $targets = $ovlens::environments.empty ? {
    true    => '--all',
    default => $ovlens::environments.join(' '),
  }

  $service = epp('ovlens/ovlens-generate.service.epp', {
    'command'         => $ovlens::command,
    'docs_dir'        => $ovlens::docs_dir,
    'environmentpath' => $ovlens::environmentpath,
    'targets'         => $targets,
  })

  systemd::timer { 'ovlens-generate.timer':
    ensure          => $ovlens::generate_ensure,
    timer_content   => epp('ovlens/ovlens-generate.timer.epp', { 'interval' => $ovlens::generate_interval }),
    service_content => $service,
    active          => $present,
    enable          => $present,
    require         => File[$ovlens::docs_dir],
  }
}
