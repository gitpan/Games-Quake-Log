package Games::Quake::Log;

#------------------------------------------------------------------------------
#
# Modification History
#
# Auth    Date       Description
# ------  ---------  ----------------------------------------------------------
# mwk     07 Dec 01  Wrote this
#------------------------------------------------------------------------------

=head1 NAME

  Games::Quake::Log - information gleaned from the output of a Quake2 DM log

=head1 SYNOPSIS

  my $q_log = Games::Quake::Log->new($log_file_with_dir_path_if_necessary);

  my %kills        = %{ $q_log->kills        };
  my %suicides     = %{ $q_log->suicides     };
  my %game         = %{ $q_log->game         };
  my %time_in_gmae = %{ $q_log->time_in_game };
  my %frequency    = %{ $q_log->frequency    };

=head1 DESCRIPTION

This module parses the log file generated by Quake2 from one of the standard
logging mods. (Personally, I use sl_dm.)

When instansiated with a log file, you can ask for certain information. This
is all the information that the log file has. So, if you want to make stats,
just rearrange into different ways! 

=cut

use strict;

use vars qw($VERSION);
$Quake::Log::VERSION = 1.01;

sub new {
  my $self = {};
  bless $self, shift;
  $self->_init(@_);
  return $self;
}

sub _init {
  my $self = shift;
  my $file = shift or die "No file given";
  open(LOG, $file) or die "Can't open file $file";

  # do I really want all this in the init? Spose not, but
  # then again, you can now ask the object for all its info.

  my $day; my $time; my $dmflags;
  
  my %hist; # time of death, who killed you in which game
  my %kills; # number of times you killed people in what game with what weapon 
  my %suicides; # number of times you killed yourself in which game in which way
  my %time_in_game; # length of time you were in a game
  my %game; # all the information on a particualr game
  my $gameid = 1;

  while (<LOG>) {
    chomp; 
    my $line = $_;
       $line =~ s/^\s+//g;
    my @bits = split "\t", $line;
    $bits[$_] ||= 0 foreach (0 .. 10);

    my $action = $bits[0];
    if ($action eq "PlayerConnect" || ($action eq "Player" && $bits[2] ne "Kill")) {
      $time_in_game{$gameid}{$bits[1]}{'entered'} = $bits[3];
      $time_in_game{$gameid}{$bits[1]}{'time'} = 0;
      next;
    } elsif ($action eq "PlayerLeft") {
      my $player = $bits[1];
      my $entered = $time_in_game{$gameid}{$player}{'entered'}  || 0;
      $time_in_game{$gameid}{$player}{'time'} += ($bits[3] - $entered);
      next;
    } elsif ($action eq "LogDate") {
      $game{$gameid}{'date'} = $bits[1];
      $day = $bits[1];
      next;
    }  elsif ($action eq "LogTime") {
      $game{$gameid}{'time'} = $bits[1];
      $time = $bits[1];
      next;
    } elsif ($action eq "GameEnd") {
      $game{$gameid}{'length'} = $bits[3];
      foreach my $player (keys %{ $time_in_game{$gameid} }) {
        $time_in_game{$gameid}{$player}{'time'} = ($bits[3] - ($time_in_game{$gameid}{$player}{'entered'} || 0));
      }
      next;
    }  elsif ($action eq "GameStart") {
      foreach my $player (keys %{ $time_in_game{$gameid} }) {
        $time_in_game{$gameid}{$player}{'time'} ||= $game{$gameid}{'length'};
      }
      $gameid++;
      # just in case these havn't changed since the last server start...
      $game{$gameid}{'dmflags'} = $dmflags;
      $game{$gameid}{'date'} = $day;
      $game{$gameid}{'time'} = $time;   
      next;
    }  elsif ($action eq "Map") {
      $game{$gameid}{'map'} = $bits[1];
      next;
    } elsif ($action eq "LogDeathFlags") {
      $game{$gameid}{'dmflags'} = $bits[1];
      $dmflags = $bits[1];
      next;
    } elsif ($bits[2] eq "Kill") {
      my $victor = $bits[0];
      my $victim = $bits[1];
      my $weapon = $bits[3] || "Silky ninja skills";
      $kills{$gameid}{$victor}{$victim}{$weapon}++;
      push @{ $hist{$gameid}{$bits[5]} }, $victor, $victim;
      next;
    } elsif ($bits[2] eq "Suicide") { 
      my $stoopid = $bits[0] or next;      
      my $way_to_go = $bits[3] or next;
      $suicides{$gameid}{$stoopid}{$way_to_go}++;
      next;
    } elsif ($action eq "PlayerRename" && $bits[2] ne "Kill") {
      $time_in_game{$gameid}{$bits[1]}{'entered'} = $bits[2];
      $time_in_game{$gameid}{$bits[1]}{'time'}    = 0;
      next;
    } elsif ($action eq "StdLog" || $action eq "PatchName") {
      next;
    } else {
      print "unknown command\n";
      my $count = 0;
      print $count++ . "$_\n" foreach @bits;
      print "\n";
      next;
    }
  }
  close LOG;
  $self->{kills}        = \%kills;
  $self->{game}         = \%game;
  $self->{suicides}     = \%suicides;
  $self->{time_in_game} = \%time_in_game;
  $self->{frequency}    = \%hist;
  $self->{number} = $gameid;
  $self;
}

=head2 kills

  my %kills = %{ $q_log->kills };

This returns a hash, in the following format:
$kills{$gameid}{$victor}{$victim}{$weapon} = $total_kills

=head2 game

  my %game = %{ $q_log->game };

This returns a hash in the following format:
$game{$gameid}{$game_flag} = $value

=head2 suicides

  my %suicides = %{ $q_log->suicides };

This returns a hash in the following format:
$suicides{$gameid}{$who}{$how_they_killed_themselves} = $total

=head2 time_in_game

  my %time_in_game = %{ $q_log->time_in_game };

This returns a hash in the following format:
$time_in_game{$gameid}{$who}{'time'} = $time_in_secs

=head2 frequency

  my %freq = %{ $q_log->frequency };

This returns a hash in the following format:
$freq{$gameid}{$when_in_game} = ($victor, $victim)

=head2 number_of_games

  my $number_of_games = $q_log->number;

Self-evident, really.

=cut

sub kills        { $_[0]->{kills}        }
sub game         { $_[0]->{game}         }
sub suicides     { $_[0]->{suicides}     }
sub time_in_game { $_[0]->{time_in_game} }
sub frequency    { $_[0]->{frequency}    }
sub number_of_games { $_[0]->{number}    }

=head1 BUGS
 
A few bizarre things happen sometimes.
 
=head1 TODO
 
Extend to cope with other mods, like CTF et al.
 
=head1 SUPP INFO
 
This is the 'return-a-hash' version of this module. I originally wrote it
with Class::DBI so I could store all the info in a mySQL database for a bit
of persistence. If you want that version, mail me and I can send it on, with
table definitions and everything!
 
=head1 AUTHOR
 
  StrayToaster <quake@stray-toaster.co.uk>
 
=cut      

return qq/I wanted to be with you alone
          And talk about the weather/;