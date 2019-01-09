##########################
# shutdown.pl
##########################
use utf8;

my $opts;

$opts->{xen_config}        = "$[xen_config]";
$opts->{xen_number_of_vms} = q{$[xen_number_of_vms]};
$opts->{xen_vmname}        = q{$[xen_vmname]};
$opts->{xen_hard_shutdown} = q{$[xen_hard_shutdown]};

$[/myProject/procedure_helpers/preamble]

$gt->shut_down();
exit($opts->{exitcode});