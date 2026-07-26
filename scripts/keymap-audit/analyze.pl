use v5.36;

# 用法: perl analyze.pl [maps.tsv]   默认 maps.base.tsv
my $file = shift(@ARGV) // 'maps.base.tsv';

my (%by_scope_mode, %desc);
open my $fh, '<', $file or die "无法打开 $file: $!";
while (<$fh>) {
    chomp;
    my ($scope, $mode, $lhs, $d) = split /\t/, $_, 4;
    next unless defined $lhs;
    push @{ $by_scope_mode{"$scope|$mode"} }, $lhs;
    $desc{"$scope|$mode|$lhs"} = $d // '';
}
say "数据源: $file";

say "";
say "=== 一、被更长映射阻塞的「完整动作」（desc 非组名，故非纯 which-key 组）===";
my $hits = 0;
for my $key (sort keys %by_scope_mode) {
    my ($scope, $mode) = split /\|/, $key;
    next unless $scope eq 'G';
    my @lhs = @{ $by_scope_mode{$key} };
    for my $short (@lhs) {
        my $d = $desc{"$scope|$mode|$short"};
        next if $d eq '' || $d =~ /^\+/;    # 纯 which-key 组，等 timeout 是设计使然
        next if length($short) > 12;
        my @longer = grep { $_ ne $short && index($_, $short) == 0 } @lhs;
        next unless @longer;
        $hits++;
        printf "%-16s %-4s %-46s 被 %d 条前缀化\n", $short, $mode, $d, scalar @longer;
    }
}
say "（无）" unless $hits;

say "";
say "=== 二、内置单键被用户映射前缀化 ===";
my @builtin = qw(w b e W B E h j k l H M L G g z Z t T f F u U p P x s S c d y r n N v V o O a i I A);
for my $mode (qw(n v x)) {
    my $list = $by_scope_mode{"G|$mode"} or next;
    my %set = map { $_ => 1 } @$list;
    for my $b (@builtin) {
        next if exists $set{$b};    # 自身已被映射，属上一节的范畴
        my @longer = sort grep { index($_, $b) == 0 && length($_) > length($b) } keys %set;
        next unless @longer;
        my $show = join ' ', @longer[ 0 .. ( $#longer > 5 ? 5 : $#longer ) ];
        $show .= sprintf ' …(共 %d)', scalar @longer if @longer > 6;
        printf "%-6s %-4s %s\n", $b, $mode, $show;
    }
}

say "";
say "=== 三、<leader> 单大写字母占用情况 ===";
my %taken;
for my $lhs ( @{ $by_scope_mode{'G|n'} // [] } ) {
    $taken{$1} = $desc{"G|n|$lhs"} if $lhs =~ m{^\ ([A-Z])$};
}
printf "  %s : %s\n", $_, $taken{$_} for sort keys %taken;
say "  空闲: @{[ grep { !$taken{$_} } 'A' .. 'Z' ]}";
