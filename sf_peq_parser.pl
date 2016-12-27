#!/usr/bin/perl -w

use strict;
use warnings;

# decleare constant
my $start_addr  = 0x007f0000;  # same as scratchpad address (e.g. 0x001f0000, 0x003f0000, 0x7f000000
my $channel_num = 10;
my $band_num    = 15;
my $peq_factor  = 3;  # Fc/Q/Gain
my $word_size   = 4;
my @channel_str = qw/FL C FR LS RS LB RB LFE LH RH END/;

# decleare local variable
my $max_read = $channel_num * $band_num * $peq_factor * $word_size;
my $buf, my $word, my $loop_word;
my $coef_factor = 0, my $read_size = 0, my $read_cnt = 0, my $cur_channel = 0;

# open file
open my $fh, '<', $ARGV[0]
    or die "Cannot open '$ARGV[0]': $!";

if ($start_addr > -s $fh) {
    die "start_addr is too big compare with file size";
}

# set stream to binary mode
binmode $fh;

# skip over program area
seek $fh, $start_addr, 0;

# read 1st data for max read
read $fh, $buf, 4;
$word = unpack("N", $buf);
$max_read = $word * 4;
#printf("Total word num : 0x%x\n",  $word);

&print_ch_divider($channel_str[$cur_channel++]);

# read data loop
while ((not eof $fh) && ($read_size < $max_read)) {
    # read data as peq index such as d5 09 xxxx
    for (my $i = 0; $i < $word_size; $i++) {
        $read_size += read $fh, $buf, 1;

        # 2nd data bytes + 1 bytes is data length after this word
        if ($i == 1) {
            $loop_word = unpack("C", $buf);
            $loop_word++;
        }
    }

    # read peq coefficient
    for (my $i = 0; $i < $loop_word; $i++, $read_cnt++) {
        if ($cur_channel >= $#channel_str+1) {
            last;
        }

        if (($read_cnt >= ($band_num * $peq_factor)) && (!($read_cnt % ($band_num * $peq_factor)))) {
            &print_ch_divider($channel_str[$cur_channel++]);
        }

        $read_size += read $fh, $buf, 4;
        $word = unpack("N", $buf);

        &print_peq_factor($coef_factor, $read_cnt / $peq_factor);

        if ($coef_factor++ == 2) {
            $coef_factor = 0;
        }
    }
}

printf("\n");

# close file
close $fh;

sub print_ch_divider {
    my $ch = shift;

    printf("\n-------------------------- %2s ---------------------------\n", $ch);
    if ($ch ne "END") {
        printf("         Fc                  Q                 Gain\n");
    }
}

sub print_peq_factor {
    my ($factor, $cnt) = @_;

    # Fc
    if ($coef_factor == 0) {
        printf("[%2d]  ", $cnt % $band_num);
#        printf("%08x  ",  $word);
        printf("%08x (%5d)    ",  $word, $word / (2 ** 12));
    # Q
    } elsif ($coef_factor == 1) {
#        printf("%08x  ",  $word);
        printf("%08x (%.1f)    ",  $word, $word / (2 ** 26));
    # Gain
    } else {
#        printf("%08x\n",  $word);
        if ($word <= (2 ** 31)) {
            printf("%08x (%.1f)\n",  $word, $word / (2 ** 26));
        } else {
            my $tmp = $word - (2 ** 32);
            printf("%08x (%.1f)\n",  $word, $tmp / (2 ** 26));
        }
    }
}

