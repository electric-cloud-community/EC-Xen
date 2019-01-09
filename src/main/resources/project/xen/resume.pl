##########################
# resume.pl
##########################
use utf8;

my $opts;

$opts->{xen_config}        = "$[xen_config]";
$opts->{xen_number_of_vms} = q{$[xen_number_of_vms]};
$opts->{xen_vmname}        = q{$[xen_vmname]};
$opts->{xen_start_paused}  = q{$[xen_start_paused]};
$opts->{xen_force}         = q{$[xen_force]};

$[/myProject/procedure_helpers/preamble]

$gt->resume();
exit($opts->{exitcode});
