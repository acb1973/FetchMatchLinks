#!/usr/bin/perl

use strict;
use Net::OAuth::Client;
use Data::Dumper;

my $debug=0;
my $tokenFile="$ENV{'HOME'}/.FetchMatchLinksTokens";
my $teamFile;
my @teams;

&processSwitches();
@teams=&getTeams($teamFile);
&showUsage() if ($#teams<0);

my %tokens = &checkForTokens();
my $app=Net::OAuthStuff->new(%tokens);

&getAccessToken($app); # will read from config file or prompt if not found

# OK, now we can get the matches for each team
foreach my $team (@teams) {
    print "Fetching matches for team '$team'...\n" if ($debug);
    my $url="http://chpp.hattrick.org/chppxml.ashx";
    print "Fetching URL: '$url'\n" if ($debug);
    my $result = $app->view_restricted_resource($url, {file=>'matches', version=>'2.6', teamID=>"$team"});
    if (($result->is_success)&&($result->content!~/<Error>/)) {
        my $xmloutput = $result->content;
        open(OUT, "> $team.xml");
        print OUT $xmloutput;
        close OUT;
        print "Wrote output for '$team' to '$team.xml'\n";
    }
    else {
        print STDERR "Error with data for team '$team', got:\n";
        print STDERR Dumper($result);
        die "\n";
    }
}

sub getTeams {
    my $file=shift;

    return @ARGV if (!length($file));

    my @retval;
    if (length($file)&&(! -f $file)) {
        die "Error: can't find team id file '$file'\n";
    }
    open(IN, $file);
    while(<IN>) {
        chomp;
        if ($_ !~ /^(\d+)$/) {
            die "Error: syntax error in '$file' line '$.':\n$_\n\nExpected team id\n";
        }
        else {
            push @retval, $1;
        }
    }
    @retval;
}

sub processSwitches {
    my @args;
    while($#ARGV>=0) {
        my $arg=shift @ARGV;
        if ($arg =~/^-/) {
            if($arg=~/^-d(ebug)*$/) {
                $debug=1;
                print "DEBUG: saw -debug switch, debug is enabled.\n";
            }
            elsif ($arg=~/^-f(ile)*$/) {
                $teamFile=shift @ARGV;
            }
            else {
                die "Error: unrecognized switch '$arg'\n";
            }
        }
        else {
            push @args, $arg;
        }
    }
    @ARGV=@args;
}

sub checkForTokens {
    my %retVal;

    open(TOK, $tokenFile);
    while(<TOK>) {
        chomp;
        my @fields=split /=/;
        $retVal{$fields[0]}=$fields[1];
        print "SETTING '$fields[0]' to '$fields[1]' from config file '$tokenFile'\n" if ($debug);
    }
    $retVal{'consumer_key'}='3tK54RweoAZboCHtDisHo3';
    $retVal{'consumer_secret'}='pYJKKyhNLkk7TLC5RtjcfukoIP7IrFFUOw8NC3S11Pi';
    return %retVal;
}

sub getAccessToken {
    my $app=shift;

    return if ($app->authorized);

    if ($debug) {
        print "We're not authorized, current app tokens are:\n";
        foreach my $key (keys %{$app->{tokens}}) {
            print "$key: $app->{tokens}->{$key}\n";
        }

    }

    print "Please go to " . $app->get_authorization_url(callback=>'oob') . "\n";
    print "Type in the code you get after authenticating here: \n";
    my $code = <STDIN>;
    chomp $code;
    print "code from website is '$code'\n" if ($debug);
    my ($access_token, $access_token_secret) = $app->request_access_token(verifier => $code);

    print "Got access_token=$access_token\naccess_token_secret=$access_token_secret\n" if ($debug);
    open(TOK, "> $tokenFile");
    print TOK "access_token=$access_token\naccess_token_secret=$access_token_secret\n";
    close(TOK);

}

sub showUsage {
    my $msg=shift;
    print STDERR "$msg\n" if (length($msg));
    die "Usage: $0 <teamids>\n\nor\n       $0 -f <file with teamids>\n";
}

package Net::OAuthStuff;

use strict;
use Net::OAuth::Simple;
use base qw(Net::OAuth::Simple);

sub new {
    my $class  = shift;
    my %tokens = @_;
    return $class->SUPER::new( tokens => \%tokens, 
        protocol_version => '1.0a',
        urls   => {
        authorization_url => 'https://chpp.hattrick.org/oauth/authorize.aspx',
        request_token_url => 'https://chpp.hattrick.org/oauth/request_token.ashx',
        access_token_url  => 'https://chpp.hattrick.org/oauth/access_token.ashx',
        oauth_callback => 'oob'
    });
}

sub view_restricted_resource {
    my $self=shift;
    my $url=shift;
    my $paramsRef=shift;
    if ($debug) {
    print STDERR "PARAMS:\n";
        foreach my $key (keys %$paramsRef) {
            print "$key = $paramsRef->{$key}\n";
        }
    }
    print STDERR "URL:$url\n" if ($debug);
    return $self->make_restricted_request($url, 'GET', %$paramsRef);
}

sub  update_restricted_resource {
    my $self=shift;
    my $url=shift;
    my %extra_params_ref=shift;
    return $self->make_restricted_request($url, 'POST', %$extra_params);    
}
1
;
