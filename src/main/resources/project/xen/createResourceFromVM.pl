##########################
# createResourceFromVM.pl
##########################
use utf8;

my $opts;

$opts->{xen_config}              = "$[xen_config]";
$opts->{xen_vmname}              = q{$[xen_vmname]};
$opts->{xen_number_of_vms}       = q{$[xen_number_of_vms]};
$opts->{ec_pools}               = q{$[ec_pools]};
$opts->{ec_workspace}           = q{$[ec_workspace]};
$opts->{ec_properties_location} = q{$[ec_properties_location]};
$opts->{tag}                     = q{$[tag]};

$[/myProject/procedure_helpers/preamble]

$gt->createResourceFromVM();
exit($opts->{exitcode});
