##########################
# cleanup.pl
##########################
use utf8;

my $opts;

$opts->{xen_config}              = "$[xen_config]";
$opts->{xen_vmname}              = q{$[xen_vmname]};
$opts->{xen_number_of_vms}       = q{$[xen_number_of_vms]};
$opts->{tag}                     = q{$[tag]};
$opts->{ec_properties_location} = q{$[ec_properties_location]};
$opts->{xen_delete}              = q{$[xen_delete]};

$[/myProject/procedure_helpers/preamble]

$gt->cleanup();
exit($opts->{exitcode});
