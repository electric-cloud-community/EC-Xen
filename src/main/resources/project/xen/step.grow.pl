use ElectricCommander;
use ElectricCommander::PropDB;

$::ec = new ElectricCommander();
$::ec->abortOnError(0);

$| = 1;

my $number   = "$[number]";
my $poolName = "$[poolName]";

my $xen_config   = "$[xen_config]";
my $xen_template = "$[xen_template]";
my $xen_network  = "$[xen_network]";
my $xen_vmname   = "$[xen_vmname]";
my $ec_workspace = "$[ec_workspace]";
my $xen_tag      = "$[tag]";

my @deparray = split(/\|/, $deplist);

sub main {
    print "Xen Grow:\n";

    # Validate inputs
    $number   =~ s/[^0-9]//gixms;
    $poolName =~ s/[^A-Za-z0-9_-\s].*//gixms;

    $xen_config   =~ s/[^A-Za-z0-9_-\s]//gixms;
    $xen_template =~ s/[^A-Za-z0-9_-\s]//gixms;
    $xen_network  =~ s/[^A-Za-z0-9_-\s]//gixms;
    $xen_vmname   =~ s/[^A-Za-z0-9_-\s]//gixms;
    $ec_workspace =~ s/[^A-Za-z0-9_-\s]//gixms;
    $xen_tag      =~ s/[^A-Za-z0-9_-\s]//gixms;

    $xen_results =~ s/[^A-Za-z0-9_\-\/\s]//gixms;

    my $xmlout = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    addXML(\$xmlout, "<GrowResponse>");

    ### CREATE VMs ###
    print("Running Xen Provision\n");
    my $proj = "$[/myProject/projectName]";
    my $proc = "Provision";
    my $xPath = $::ec->runProcedure(
                                    "$proj",
                                    {
                                       procedureName   => "$proc",
                                       pollInterval    => 1,
                                       timeout         => 3600,
                                       actualParameter => [{ actualParameterName => "ec_pools", value => "$poolName" }, { actualParameterName => "ec_properties_location", value => "/myJob/Xen/vms/" }, { actualParameterName => "ec_workspace", value => "$ec_workspace" }, { actualParameterName => "tag", value => "$xen_tag" }, { actualParameterName => "xen_config", value => "$xen_config" }, { actualParameterName => "xen_createresource", value => "1" }, { actualParameterName => "xen_network", value => "$xen_network" }, { actualParameterName => "xen_number_of_vms", value => "$number" }, { actualParameterName => "xen_template", value => "$xen_template" }, { actualParameterName => "xen_vmname", value => "$xen_vmname-$[jobStepId]" }, { actualParameterName => "xen_timeout", value => "" },],
                                    }
                                   );
    if ($xPath) {
        my $code = $xPath->findvalue('//code');
        if ($code ne "") {
            my $mesg = $xPath->findvalue('//message');
            print "Run procedure returned code is '$code'\n$mesg\n";
        }
    }
    my $outcome = $xPath->findvalue('//outcome')->string_value;
    if ("$outcome" ne "success") {
        print "Xen Provision job failed.\n";
        
        if ($depobj->getProp("/jobs/$jobId/Xen/vms/$xen_tag/vmsList") eq "")
        {
        exit 1;}
        
        
    }
    my $jobId = $xPath->findvalue('//jobId')->string_value;
    if (!$jobId) {
        exit 1;
    }

    my $depobj = new ElectricCommander::PropDB($::ec, "");
    my $vmsList = $depobj->getProp("/jobs/$jobId/Xen/vms/$xen_tag/vmsList");
    print "VM list=$vmsList\n";

    my @vms = split(/;/, $vmsList);
    my $createdList = ();

    my $xmlout = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>";
    addXML(\$xmlout, "<GrowResponse>");
    foreach my $vm (@vms) {
        addXML(\$xmlout, "  <Deployment>");
        addXML(\$xmlout, "      <handle>$vm</handle>");
        addXML(\$xmlout, "      <hostname>" . $depobj->getProp("/jobs/$jobId/Xen/vms/$xen_tag/$vm/IP_Address") . "</hostname>");
        addXML(\$xmlout, "      <VM>" . $depobj->getProp("/jobs/$jobId/Xen/vms/$xen_tag/$vm/Name") . "</VM>");
        addXML(\$xmlout, "      <resource>" . $depobj->getProp("/jobs/$jobId/Xen/vms/$xen_tag/$vm/Resource") . "</resource>");
        addXML(\$xmlout, "      <uuid>" . $depobj->getProp("/jobs/$jobId/Xen/vms/$xen_tag/$vm/uuid") . "</uuid>");
        addXML(\$xmlout, "      <ref>" . $depobj->getProp("/jobs/$jobId/Xen/vms/$xen_tag/$vm/VM_ref") . "</ref>");
        addXML(\$xmlout, "      <results>/jobs/$jobId/Xen/vms</results>");
        addXML(\$xmlout, "      <tag>$xen_tag</tag>");
        addXML(\$xmlout, "  </Deployment>");
    }

    addXML(\$xmlout, "</GrowResponse>");

    my $prop = "/myJob/CloudManager/grow";
    print "Registering results for $vmList in $prop\n";
    $::ec->setProperty("$prop", $xmlout);
}

sub addXML {
    my ($xml, $text) = @_;
    ## TODO encode
    ## TODO autoindent
    $$xml .= $text;
    $$xml .= "\n";
}

main();
