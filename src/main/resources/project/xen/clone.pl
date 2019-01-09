##########################
# clone.pl
##########################
use warnings;
use strict;
use Encode;
use utf8;
use open IO => ':encoding(utf8)';

my $opts;

$opts->{xen_config}             = "$[xen_config]";
$opts->{xen_number_of_clones}   = q{$[xen_number_of_clones]};
$opts->{xen_original_vmname}    = q{$[xen_original_vmname]};
$opts->{xen_vmname}             = q{$[xen_vmname]};
$opts->{tag}                    = q{$[tag]};
$opts->{ec_properties_location} = q{$[ec_properties_location]};
$opts->{xen_createresource}     = q{$[xen_createresource]};
$opts->{ec_pools}               = q{$[ec_pools]};
$opts->{ec_workspace}           = q{$[ec_workspace]};

$[/myProject/procedure_helpers/preamble]

$gt->clone();
exit($opts->{exitcode});
