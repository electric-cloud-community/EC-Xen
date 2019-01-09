##########################
# provision.pl
##########################
use warnings;
use strict;
use Encode;
use utf8;
use open IO => ':encoding(utf8)';

my $opts;

$opts->{xen_config}             = "$[xen_config]";
$opts->{xen_number_of_vms}      = q{$[xen_number_of_vms]};
$opts->{xen_template}           = q{$[xen_template]};
$opts->{xen_network}            = q{$[xen_network]};
$opts->{xen_vmname}             = q{$[xen_vmname]};
$opts->{ec_pools}               = q{$[ec_pools]};
$opts->{ec_workspace}           = q{$[ec_workspace]};
$opts->{ec_properties_location} = q{$[ec_properties_location]};
$opts->{tag}                    = q{$[tag]};
$opts->{xen_createresource}     = q{$[xen_createresource]};

$[/myProject/procedure_helpers/preamble]

$gt->provision();
exit($opts->{exitcode});
