##########################
# reboot.pl
##########################
use utf8;

my $opts;

$opts->{xen_config}        = "$[xen_config]";
$opts->{xen_number_of_vms} = q{$[xen_number_of_vms]};
$opts->{xen_vmname}        = q{$[xen_vmname]};
$opts->{xen_hard_reboot}   = q{$[xen_hard_reboot]};

$[/myProject/procedure_helpers/preamble]

$gt->reboot();
exit($opts->{exitcode});
