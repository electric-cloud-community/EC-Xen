use ElectricCommander;
use File::Basename;
use ElectricCommander::PropDB;
use ElectricCommander::PropMod;
use Encode;
use utf8;

$| = 1;

use constant {
               SUCCESS => 0,
               ERROR   => 1,
             };

# Create ElectricCommander instance
my $ec = new ElectricCommander();
$ec->abortOnError(0);

my $pluginKey  = 'EC-Xen';
my $xpath      = $ec->getPlugin($pluginKey);
my $pluginName = $xpath->findvalue('//pluginVersion')->value;
print "Using plugin $pluginKey version $pluginName\n";
$opts->{pluginVer} = $pluginName;

my $cfgName = $opts->{xen_config};
print "Loading config $cfgName\n";

my $proj = "$[/myProject/projectName]";
my $cfg = new ElectricCommander::PropDB($ec, "/projects/$proj/xen_cfgs");

if (!defined($cfg) || $cfg eq "") {
    print "Configuration [$cfgName] does not exist\n";
    exit 1;
}

# Add the option from the connection config
my %vals = $cfg->getRow($cfgName);
foreach my $c (keys %vals) {
    print "Adding config $c=$vals{$c}\n";
    $opts->{$c} = $vals{$c};
}

# Check that credential item exists
if (!defined $opts->{credential} || $opts->{credential} eq "") {
    print "Configuration [$cfgName] does not contain a Xen credential\n";
    exit 1;
}

# Get user/password out of credential named in $opts->{credential}
$xpath            = $ec->getFullCredential("$opts->{credential}");
$opts->{xen_user} = $xpath->findvalue("//userName");
$opts->{xen_pass} = $xpath->findvalue("//password");

# Check for required items
if (!defined $opts->{xen_server} || $opts->{xen_server} eq "") {
    print "Configuration [$cfgName] does not contain a Xen server name\n";
    exit 1;
}
if (!defined $opts->{xen_user} || $opts->{xen_user} eq "") {
    print "Credential [$opts->{credential}] does not contain a username\n";
    exit 1;
}
if (!defined $opts->{xen_pass} || $opts->{xen_pass} eq "") {
    print "Credential [$opts->{credential}] does not contain a password\n";
    exit 1;
}

$opts->{JobId}     = "$[/myJob/jobId]";
$opts->{JobStepId} = "$[/myJobStep/jobStepId]";

# Load the actual code into this process
if (!ElectricCommander::PropMod::loadPerlCodeFromProperty($ec, "/myProject/xen_driver/Xen")) {
    print "Could not load Xen.pm\n";
    exit 1;
}

# Make an instance of the object, passing in options as a hash
my $gt = new Xen($ec, $opts);

