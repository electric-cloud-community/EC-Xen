##########################
# step.sync.pl
##########################
use ElectricCommander;
use ElectricCommander::PropDB;
use strict;
use warnings;

$::ec = new ElectricCommander();
$::ec->abortOnError(0);

$| = 1;

my $opts;
my $xen_config  = "$[xen_config]";
my $deployments = '$[deployments]';

$opts->{xen_config} = q{$[xen_config]};
$[/myProject/procedure_helpers/preamble]





sub main {
    print "Xen Sync:\n";

    # unpack request
    my $xPath = XML::XPath->new(xml => $deployments);
    my $nodeset = $xPath->find('//Deployment');

    my $instanceList = "";

    # put request in perl hash
    my $deplist;
    foreach my $node ($nodeset->get_nodelist) {

        # for each deployment
        my $i = $xPath->findvalue('handle', $node)->string_value;
        my $s = $xPath->findvalue('state',  $node)->string_value;    # alive
        my $vm_ref    = $xPath->findvalue('ref',        $node)->string_value;
        print "Input: $i state=$s\n";
        $deplist->{$i}{state}  = "alive";                            # we only get alive items in list
        $deplist->{$i}{result} = "alive";
        $deplist->{$i}{vm_ref}  = $vm_ref;
        $instanceList .= "$i\;";
    }

    checkIfAlive($instanceList, $deplist);

    my $xmlout = "";
    addXML(\$xmlout, "<SyncResponse>");
    foreach my $handle (keys %{$deplist}) {
        my $result = $deplist->{$handle}{result};
        my $state  = $deplist->{$handle}{state};

        addXML(\$xmlout, "<Deployment>");
        addXML(\$xmlout, "  <handle>$handle</handle>");
        addXML(\$xmlout, "  <state>$state</state>");
        addXML(\$xmlout, "  <result>$result</result>");
        addXML(\$xmlout, "</Deployment>");
    }
    addXML(\$xmlout, "</SyncResponse>");
    $::ec->setProperty("/myJob/CloudManager/sync", $xmlout);
    print "\n$xmlout\n";
    exit 0;
}

# checks status of instances
# if found to be stopped, it marks the deplist to pending
# otherwise (including errors running api) it assumes it is still running
sub checkIfAlive {
    my ($instances, $deplist) = @_;
    
    # Initialize
    $gt->initialize();
    if ($gt->opts->{exitcode}) { return; }
    $gt->initialize_prop_prefix;
    if ($gt->opts->{exitcode}) { return; }
    
    my ($session, $xen) = $gt->login();
    if ($gt->ecode) { return; }
    
    foreach my $handle (keys %{$deplist}) {

        # deployment specific response
        my $state = $gt->checkStatus($session, $xen, $deplist->{$handle}{vm_ref});

        my $err = "success";
        my $msg = "";
        if ("$state" eq "Running") {
            print("VM $handle still running\n");
            $deplist->{$handle}{state}  = "alive";
            $deplist->{$handle}{result} = "success";
            $deplist->{$handle}{mesg}   = "instance still running";
        }
        else {
            print("VM $handle stopped\n");
            $deplist->{$handle}{state}  = "pending";
            $deplist->{$handle}{result} = "success";
            $deplist->{$handle}{mesg}   = "VM $handle was manually stopped or failed";
        }

    }
    $gt->logout($session, $xen);
    if ($gt->ecode) { return; }
    return;
}

sub addXML {
    my ($xml, $text) = @_;
    ## TODO encode
    ## TODO autoindent
    $$xml .= $text;
    $$xml .= "\n";
}

main();
