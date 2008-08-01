#!/usr/bin/perl
# Written by Craig Maloney
# (c) 2005 Craig Maloney
# Modified Nov-Dec. 2005 by Lars Huttar (lars AT huttar dot net)
# Released under the GPL



# Use Unicode:
use open ':utf8';
use open ':std';

$version_number = "1.4.2";
use Getopt::Long;

# DEFAULTS
$debug = 0; # Print debugging messages or not
$wordfile = "/usr/share/dict/words"; # Location of the words to use by default
$num_of_words = 50; # Number of words to place in puzzle
$gridsize = 40; # How big should the puzzle be?
$directions = 8; # Number of directions?
$max_iterations = 5; 	# Maximum number of times to try before using drastic measures
$nogrow = 0; # Don't grow the puzzle beyond the initial size
$svg = 0; # Print solutions in SVG format 
$finished = 0; 	# Main loop toggle
$lowercase = 0; # Toggle lowercase
$checkunique = 0; # Check to see if words are unique 
$intersections = 0; # Number of cells where words intersect
$rtl = 0; # Use right-to-left instead of left-to-right
$min_word_length = 5; # Minimum word length 
$similar_words = 0; # Don't allow duplicates at $min_word_length number of letters
$fillalphabet = 0; # Use the letters from the wordlist
$no_normalize = 0; # Allow the input to be used as it is, no post processing
$all = 0; # Don't use all of the words

# List of words to choose from.
@wordlist = ();
# List of words chosen for puzzle.
@selected_words = ();
# Offsets for the eight directions.
@x_offset = (1,0,0,-1,1,1,-1,-1); # R,D,U,L,UR,DR,DL,UL
@y_offset = (0,1,-1,0,-1,1,1,-1); # R,D,U,L,UR,DR,DL,UL

# @fillwith = split //, "ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ";
# @fillwith = split //, "_";

GetOptions ("size=i" => \$gridsize,
	"directions=i" => \$directions,
	"words=i" => \$num_of_words,
	"all" => \$all,
	"wordfile=s" => \$wordfile,
	"fillwithquote" => \$fillwithquote,
	"fillalphabet" => \$fillalphabet,
	"checkunique" => \$checkunique,
	"lowercase" => \$lowercase,
	"debug" => \$debug,
	"nosolution" => \$nosolution,
	"svg" => \$svg,
	"nogrow" => \$nogrow,
	"version" => \$version,
	"quick" => \$quick,
	"thorough" => \$thorough,
	"righttoleft" => \$rtl,
	"similarwords" => \$similar_words,
	"minwordlength=i" => \$min_word_length,
	"nonormalize" => \$no_normalize,
	"help" => \$help );
# all = try to place every word in the wordlist into the puzzle.

if ($help) {
	&usage;
	exit(0);
}

if ($version) {
	print "$0 version: $version_number\n";
	exit(0);
}

if ($quick) {
	$max_iterations = 1;
}

if ($thorough) {
	$max_iterations = 20;
}

open WORDLIST, "$wordfile" || die "Can't open wordlist $wordfile\n";
foreach $i (<WORDLIST>) {
	chomp $i; # remove line ending
	next if length $i < $min_word_length;
	push @wordlist, normalize($i) if ($i ne '' && $i ne ' ');
}
close WORDLIST;

if ($fillwithquote) {
    # Last line becomes a quote to use as filler.
    @fillwith = split('', normalize(pop @wordlist));
}

# Randomize the list
for ($i = ((scalar @wordlist)); --$i; ) {
	my $j = int rand ($i);
	next if $i == $j;
	@wordlist[$i,$j] = @wordlist[$j,$i];
}

if ($all) {
	$num_of_words = scalar @wordlist;
	@selected_words = @wordlist;
	$similar_words = 1;
}

if (!$similar_words) { # Remove similar words
	my %duplicate_words = ();
	$i = 0;
	while (($i < $num_of_words) && (scalar @wordlist > 0)) {
		my $word = pop @wordlist;
		if ($duplicate_words{substr($word,0,$min_word_length)} != 1) {
			$duplicate_words{substr($word,0,$min_word_length)} = 1;
			push @selected_words, $word;
			$i++;
		} else {
			warn "Word too similar: $word\n";
		}
	}

	if (scalar @selected_words < $num_of_words) {
		$num_of_words = scalar @selected_words;
		warn "Updating number of words to $num_of_words\n";
	}
}

die "No words to use. Exiting.\n" if (scalar @selected_words <= 0);

@wordlist = ();
@selected_words = sort { length $a <=> length $b } @selected_words;

# @fillwith = set of letters to use for filling in blanks: Use letters from
# hidden words.  This gets rid of the problem of using A-Z when the hidden
# words are in other alphabets.  It also makes the puzzle harder by making
# "foreground and background" more closely resemble each other in letter
# frequency.
if (!$fillwithquote && !$fillalphabet) {
		@fillwith = split (//, join('', @selected_words)); 
} else { 
		@fillwith = split //, normalize("ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ");
}

# Main loop
do {
	$completely_done = $num_of_words;
	$number_of_iterations=0;
	$words_placed = 0;
            # Arrays storing placement of words. This should be a 2D array or some more
            # sophisticated data structure, instead of 3 arrays; but I (Lars) find those too difficult in Perl. :-(
            @word_x_starts = ();
            @word_y_starts = ();
            @word_dirs = ();

	while ($completely_done > 0 && $number_of_iterations < $max_iterations) {
		print "Creating new puzzle $number_of_iterations\n" if $debug;
		$intersections = 0;
		$spaces_left = $gridsize * $gridsize;
		$number_of_iterations++;
		$completely_done = $num_of_words;
		$success = 1;
		@new_word_list = @selected_words;
		&clear_grid;
		while (($new_word = pop @new_word_list) && $success) {
			print "Placing $new_word\n" if $debug;
			$results = &place_word($new_word, $gridsize, $directions);
			if ($results == 0) {
				$completely_done--; 
                                    	$words_placed++;
			} else {
				print "iterating over grid\n" if $debug;
				$results = &iterate_word($new_word, $gridsize, $directions);
				if ($results != 0) {
					print "Grid iteration didn't work either\n" if $debug;
					$success = 0;
				} else {
					$completely_done--;
                                                	$words_placed++;
				}
			}
		}
	}
	print "Number of main loop iterations = $number_of_iterations\n" if $debug;
	if ($completely_done > 0) {
		if ($nogrow) {
			die "Can't create wordsearch with these parameters. Aborting.\n";
		} else {
			$gridsize += 5;
			warn "Increasing gridsize to $gridsize\n";
		}
	}
	if ($fillwithquote) {
	           if  (scalar @fillwith != $spaces_left) {
	               print "Spaces left: $spaces_left != quote length: ", scalar @fillwith, ".\n" if $debug;
   	               print_grid(1) if $debug;
                           if ($number_of_iterations >= $max_iterations) { $finished = 1; }
	               else { print "Trying again.\n" if $debug; }
	           } else {
	               print "Quote fits in remaining spaces!\n" if $debug;
	               $finished = 1;
	           }
	} else {
                        $finished = 1;
	}
} until ($finished);

print "\n";

if (!$nosolution && !$svg) {
	&print_grid(1);
	print "\n";
}

&fill_in();
if ($checkunique) { check_unique(); }
print "\n";

if (!$nosolution && $svg) {
            &print_solution_svg();
            print "\n";
}

&print_grid(0);
print "\n\n";

@selected_words = sort @selected_words;
&print_words;

exit(0);

# Try to place word randomly; return 0 if successful.
sub place_word {
	my ($word, $size, $possible_directions) = @_;
	my $done = 0;
	@letters = split //,$word;
	$iteration_counter = 0;

            # First, try to place word in a way that intersects another word.
	while (!$done && $words_placed > 0 && ($size * $size * 0.1 >= $iteration_counter) ) {
		$x = int (rand $size);
		$y = int (rand $size);

		if (!is_empty($x, $y) && $word =~ /$grid[$y][$x]/)
		{
			$done = &try_word_around($word, $x, $y, $size, $possible_directions);
		}

		$iteration_counter++;
	}
	if ($done && $debug) {
	    print "Placed word intersectingly\n";
	    print_grid(1);
	}

            if (!$done) {
                        # If that didn't work, just try to place the word randomly. 
            	$iteration_counter = 0;            
                        
            	while (!$done && (2*$num_of_words >= $iteration_counter) ) {
            		$x = int (rand $size);
            		$y = int (rand $size);
            
            		#if (is_empty($x, $y)) 
            		{
            			$done = &test_word_position($x, $y, $size, $possible_directions);
            		}
            
            		$iteration_counter++;
            	}
            }
            
	if (!$done) {
		print "Random iterations failed: $iteration_counter\n" if $debug;
		return 1;
	}
	print "Random Iterations $iteration_counter\n" if $debug;
	return 0;
}

# Try to place word systematically; return 0 if successful.
sub iterate_word {
	my ($word,$size,$possible_directions) = @_;
	my $done = 0;
	@letters = split //,$word;
	my $x=0;
	my $y=0;
	while (!$done && ($y<$size) ) {
		if (is_empty($x, $y)) {
			$done = &test_word_position($x,$y,$size,$possible_directions);
		}

		$x++;
		if ($x>=$size) {
			$x=0;
			$y++;
		}
	}
	if (!$done) {
		return 1;
	}
	return 0;
}

sub print_grid {
	my $solution = shift;
	if ($solution && $svg) {
	    print_solution_svg();
	} else {
                print "Solution:\n" if $solution;
                for ($i=0; $i<$gridsize; $i++) {
                	for ($j=0; $j<$gridsize; $j++) {
                            	print $grid[$i][$j], " ";
                	}
                	print "\n";
                }
                print("Intersections: $intersections\n") if $debug;
            }
}

sub print_solution_svg() {
        my $margin = 20;
        my $dx = 20;
        my $dy = 20;
        print "Solution:\n";
        print "<?xml version='1.0' encoding='UTF-8'?>\n";
        print "<!DOCTYPE svg PUBLIC '-//W3C//DTD SVG 1.0//EN' 'http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd'>\n";
        print "<svg xmlns='http://www.w3.org/2000/svg' width='100%' height='100%'>\n";
        print "  <g style='stroke-linecap: round; stroke: #7777ff; stroke-width: 6; opacity: 0.5'>\n";
        for ($i = 0; $i < $words_placed; $i++ ) {
            my $word = $selected_words[$i];
            printf("    <!-- word: %s -->\n", $selected_words[$i], 1);
            my $x1 = $margin + $word_x_starts[$i] * $dx - 2;
            my $y1 = $margin + $word_y_starts[$i] * $dy - 6;
            my $x2 = $x1 + $x_offset[$word_dirs[$i]] * $dx * (length($word)-1);
            my $y2 = $y1 + $y_offset[$word_dirs[$i]] * $dy * (length($word)-1);
            printf("    <line x1='%d' y1='%d' x2='%d' y2='%d'/>\n", $x1, $y1, $x2, $y2);
        }
        print "  </g>\n";
        print "  <text style='text-anchor: middle'>\n";
        for ($i=0; $i<$gridsize; $i++) {
            for ($j=0; $j<$gridsize; $j++) {
                my $x = $margin + $j * $dx;
                my $y = $margin + $i * $dy;
                printf("    <tspan x='%d' y='%d'>%s</tspan>\n", $x, $y, $grid[$i][$j]);
            }
            print "\n";
        }
        print "  </text>\n";
        
        print "</svg>\n";
        print("Intersections: $intersections\n") if $debug;
}

# Fill in remaining spaces with either letters from the quote, or random letters.
sub fill_in {
    my $quoteindex = 0;
    for ($i=0; $i < $gridsize; $i++) {
        if ($fillwithquote) {
            if ($rtl) {
                # Right to left
        	    for ($j = $gridsize-1; $j >= 0; $j--) {
           	        if (is_empty($j, $i)) {
                        if ($quoteindex > $#fillwith) { $grid[$i][$j] = '_'; }
                        else { $grid[$i][$j] = $fillwith[$quoteindex++]; }
                    }
                }    
            } else {
        	    for ($j=0; $j < $gridsize; $j++) {
           	        if (is_empty($j, $i)) {
                        if ($quoteindex > $#fillwith) { $grid[$i][$j] = '_'; }
                        else { $grid[$i][$j] = $fillwith[$quoteindex++]; }
                    }
        	    }
            }
        } else {
            for ($j=0; $j < $gridsize; $j++) {
               if (is_empty($j, $i)) {
                    $grid[$i][$j] = $fillwith[rand @fillwith];
               }
            }
        }
    } 
}

# is_empty($x, $y):
# Return a true value if the grid cell at x,y is empty.
sub is_empty {
    my $x = shift;
    my $y = shift;
    return ($grid[$y][$x] eq '' || $grid[$y][$x] eq '-');
}


# Display the words to search for, in multi-column format.
sub print_words {
	# Copied from Perl Cookbook by Tom Christiansen & Nathan Torkington
	# Recipie 4.18
	my ($item, $cols, $rows, $maxlen);
	my ($xpixel, $ypixel, $mask, @data);
	$cols = 80;
	$maxlen = 1;        
	foreach $word (@selected_words) {
		my $mylen;
		$word =~ s/\s+$//;
		$maxlen = $mylen if (($mylen = length $word) > $maxlen);
		push(@data, $word);
	}

	$maxlen += 1;               # to make extra space

	# determine boundaries of screen
	$cols = int($cols / $maxlen) || 1;
	$rows = int(($#data+$cols) / $cols);

	# pre-create mask for faster computation
	$mask = sprintf("%%-%ds ", $maxlen-1);

	# subroutine to check whether at last item on line
	sub EOL { ($item+1) % $cols == 0 }  

	# now process each item, picking out proper piece for this position
	for ($item = 0; $item < $rows * $cols; $item++) {
		my $target =  ($item % $cols) * $rows + int($item/$cols);
		my $piece = sprintf($mask, $target < @data ? $data[$target] : "");
		$piece =~ s/\s+$// if EOL();  # don't blank-pad to EOL
			print $piece;
		print "\n" if EOL();
	}

	# finish up if needed
	print "\n" if EOL();
}

# Given a cell $orig_y,$orig_x that contains a letter that's somewhere in $word,
# try to place $word so that it passes through $orig_y,$orig_x. Return 1 on success.
# Global @letters contains letters of $word.
sub try_word_around {
	my $word = shift;
	my $orig_x = shift;
	my $orig_y = shift;
	my $size = shift;
	my $possible_directions = shift;
	my $direction;
	my $letter = $grid[$orig_y][$orig_x];
	my $index; # occurrence of the letter in the word
	$done = 0;
	@direction_choices = ();

            # For each occurrence of $letter in $word...
            for ($index = index($word, $letter); $index != -1 && !$done; $index = index($word, $letter, $index+1)) {
                        # Try all possible directions but don't commit to any of them.
            	for ($direction = 0; $direction<$possible_directions; $direction++) {
            		my $x = $orig_x - ($index * $x_offset[$direction]);
            		my $y = $orig_y - ($index * $y_offset[$direction]);
            		$error = 0;
            
            		foreach $letter (@letters) {
            			if ($x < 0) {
            				$x=0;
            				$error = 1;
            			}
            			if ($x >= $size) {
            				$x=$size;
            				$error = 1;
            			}
            			if ($y < 0) {
            				$y=0;
            				$error = 1;
            			}
            			if ($y >= $size) {
            				$y=$size;
            				$error = 1;
            			}
            			if (!is_empty($x, $y)) { 
            				if ($grid[$y][$x] ne $letter)  {
            					$error = 1;
            				}
            			}
            			$x+= $x_offset[$direction];
            			$y+= $y_offset[$direction];
            
            		}
            		if (0 == $error) {
            			push @direction_choices, $direction;
            		} else {
            			next;
            		}
            	}
            	# OK, pick one of the directions that works for this word, if any,
            	# and put the word there.
            	if (0 < scalar @direction_choices ) {
            		print "Direction choices: " . scalar @direction_choices . "\n" if $debug;

            		$rand_direction = @direction_choices[int(rand scalar @direction_choices)];
            		print "$rand_direction\n" if $debug;
            
            		my $x = $orig_x - ($index * $x_offset[$rand_direction]);
            		my $y = $orig_y - ($index * $y_offset[$rand_direction]);
                          # was: $word_x_starts[$words_placed] = $x;
                          # was: $word_y_starts[$words_placed] = $y;
                          # was: $word_dirs[$words_placed] = $rand_direction;
                          unshift(@word_x_starts, $x);
                          unshift(@word_y_starts, $y);
                          unshift(@word_dirs, $rand_direction);

            		foreach $letter (@letters) {
            			if (is_empty($x, $y)) { 
                                    		$spaces_left--;
            				$grid[$y][$x] = $letter;
            			} elsif ($grid[$y][$x] eq $letter)  {
                        			$intersections++;			
            			} else {
            				die &print_grid;
            			}
            			$x+= $x_offset[$rand_direction];
            			$y+= $y_offset[$rand_direction];
            		}
            		$done = 1;
            	}
            }
	return $done;
}

# Try to place $word starting at cell $x,$y.
# On success, place the word and return 1.
sub test_word_position {
	my $orig_x = shift;
	my $orig_y = shift;
	my $size = shift;
	my $possible_directions = shift;
	my $direction;
	$done = 0;
	@direction_choices = ();

	for ($direction = 0; $direction < $possible_directions; $direction++) {
		my $x = $orig_x;
		my $y = $orig_y;
		$error = 0;

		foreach $letter (@letters) {
			if ($x <= 0) {
				$x=0;
				$error = 1;
			}
			if ($x >= $size) {
				$x=$size;
				$error = 1;
			}
			if ($y <= 0) {
				$y=0;
				$error = 1;
			}
			if ($y >= $size) {
				$y=$size;
				$error = 1;
			}
			if (!is_empty($x, $y)) { 
				if ($grid[$y][$x] ne $letter)  {
					$error = 1;
				}
			}
			$x+= $x_offset[$direction];
			$y+= $y_offset[$direction];

		}
		if (0 == $error) {
			push @direction_choices, $direction;
		} else {
			next;
		}
	}
	if (0 < scalar @direction_choices ) {
		print "Direction choices: " . scalar @direction_choices . "\n" if $debug;
		my $x = $orig_x;
		my $y = $orig_y;
		$rand_direction = @direction_choices[int(rand scalar @direction_choices)];
		print "$rand_direction\n" if $debug;
                          # was: $word_x_starts[$words_placed] = $x;
                          # was: $word_y_starts[$words_placed] = $y;
                          # was: $word_dirs[$words_placed] = $rand_direction;
                          unshift(@word_x_starts, $x);
                          unshift(@word_y_starts, $y);
                          unshift(@word_dirs, $rand_direction);

		foreach $letter (@letters) {
			if (is_empty($x, $y)) { 
                        		$spaces_left--;
				$grid[$y][$x] = $letter;
			} elsif ($grid[$y][$x] eq $letter)  {
            			$intersections++;			
			} else {
				die &print_grid;
			}
			$x+= $x_offset[$rand_direction];
			$y+= $y_offset[$rand_direction];
		}
		$done = 1;
	}
	return $done;
}

sub clear_grid {
	for ($i=0; $i < $gridsize; $i++) {
		for ($j=0; $j < $gridsize; $j++) {
			$grid[$i][$j] = '-';
		}
	}
}

# Uppercase, strip diacritics, etc.
# Thanks to http://www.ahinea.com/en/tech/accented-translate.html for help on this.
sub normalize {
	if ($no_normalize) {
		$_ = shift;
		return $_;
	}
	use Unicode::Normalize;
	$_ = NFD(shift);  # decompose (with compatibility mapping)
	s/[^\pL]//g; # strip diacritics, spaces, punctuation, and
		     # anything that's not a letter
	# Replace positional forms with "normal" form, e.g. Greek small final
	# sigma with nonfinal sigma # I thought NFKD normalization was supposed
	# to accomplish this, but it doesn't seem to do it. If anybody knows
	# how to do this in a more general way, please let me know. 

	# Greek sigma; Hebrew kaf, mem, nun, peh, tsadeh 
	tr/\x{03C2}\x{05da}\x{05dd}\x{05df}\x{05e3}\x{05e5}/\x{03C3}\x{05db}\x{05de}\x{05e0}\x{05e4}\x{05e6}/;
	if ($lowercase) {
		$_ = lc $_ 
	} else {
		$_ = uc $_;
	}
	return $_;
}

# Check that no word can be found in the puzzle in two different places.
# If so, warn the user.
sub check_unique {
    my $ok = 1;
    foreach $word (@selected_words) {
#        print "Checking unique solution for $word\n" if $debug;
        if (find_word($word) > 1) {
            print "Warning: $word appears more than once.\n";
            $ok = 0;
        }
    }
    return $ok;
}

# Search for $word in the grid. Return 0 if not found, 1 if it occurs exactly once,
# 2 if it occurs more than once.
sub find_word {
    my $word = shift;
    my @letters = split(//, $word);
    my $occurrences = 0;
    for (my $i=0; $i < $gridsize; $i++) {
        for (my $j=0; $j < $gridsize; $j++) {
            if ($grid[$i][$j] eq $letters[0])  {
#                print "Looking at $i,$j\n" if $debug;

                for (my $dir = 0; $dir < $directions; $dir++) {
#                    print "Dir $dir\n" if $debug;
                    $error = 0;
                    my $x = $j;
                    my $y = $i;
            
                    foreach $letter (@letters) {
                    	if ($x < 0 || $x >= $gridsize || $y < 0 || $y >= $gridsize || $grid[$y][$x] ne $letter)  {
                            $error = 1;
                            last;
                    	}
                    	$x += $x_offset[$dir];
                    	$y += $y_offset[$dir];
                    }
                    if (!$error) {
                        $occurrences++;
                        if ($occurrences > 1) { return 2; }
                    }
                }
            }
        }
    }
    return $occurrences;
}

sub usage {
	print "Usage: $0 [OPTION] \n";
	print "Creates a word search puzzle.\n";
	print "\n";
	print " --size		Size of the grid (default=$gridsize).\n";
	print " --directions	Directions to place words (default=$directions).\n";
	print "		(Diagonals and reverse words = 8, No diagonals = 4,\n		 No reverse words = 2)\n";
	print " --words	Number of words to select (default=$num_of_words)\n";
	print " --fillwithquote\n		Use last word of wordfile as a quote to fill in leftover spaces\n";
	print "		(Otherwise use random letters [the default])\n";
	print " --righttoleft	Fill in right-to-left (applies only when fillwithquote is true)\n";
	print " --lowercase	Change all letters to indicated case: upper (default),\n";
	print "		lower, or none (no change).\n";
	print " --checkunique	Check that each word is found only once in the grid\n";
	print "		(default=$checkunique).\n";
	print " --wordfile	Read words from a file instead of from default location.\n";
	print "		(Currently $wordfile)\n";
	print " --similarwords	Allow words that are similar to each other\n";
	print "		(default=$similar_words)\n";
	print " --minwordlength Minimum word length to check for similarity\n";
	print "		(default=$min_word_length)\n";
	print " --all		Use all words from the list of words provided.\n";
	print " 		(DO NOT USE THIS WITH THE DEFAULT WORD LIST LOCATION!)\n";
	print " --nonormalize	Don't try to normliaze the input file\n";
	print "		(useful for number searches)\n";
	print " --nosolution	Don't display the solution.\n";
	print " --svg		Use SVG to display the solution \n		(ignored if --nosolution is used).\n"; 
	print " --nogrow	Don't grow the grid to find a solution.\n";
	print " --quick	Iterate one time through before trying new parameters.\n";
	print " --thorough	Iterate many more times through before trying new parameters.\n";
	print " --debug	Display debugging output.\n";	
	print " --version	Display the version number.\n";
	print " --help		Display this help file.\n";
	print "\nReport bugs to <craig\@decafbad.net>\n"
}
