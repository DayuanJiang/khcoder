package gui_window::word_netgraph;
use base qw(gui_window);

use strict;
use Tk;

use gui_widget::tani;
use gui_widget::hinshi;
use mysql_crossout;
use kh_r_plot;

my $bench = 0;

#-------------#
#   GUI作製   #

sub _new{
	my $self = shift;
	my $mw = $::main_gui->mw;
	my $win = $self->{win_obj};
	$win->title($self->gui_jt($self->label));

	my $lf_w = $win->LabFrame(
		-label => 'Words',
		-labelside => 'acrosstop',
		-borderwidth => 2,
	)->pack(-fill => 'both', -expand => 1, -side => 'left');

	$lf_w->Label(
		-text => gui_window->gui_jchar('■集計単位と語の選択'),
		-font => "TKFN",
		-foreground => 'blue'
	)->pack(-anchor => 'w', -pady => 2);

	$self->{words_obj} = gui_widget::words->open(
		parent => $lf_w,
		verb   => '利用',
	);

	my $lf = $win->LabFrame(
		-label => 'Options',
		-labelside => 'acrosstop',
		-borderwidth => 2,
	)->pack(-fill => 'x', -expand => 0);

	$lf->Label(
		-text => $self->gui_jchar('■共起ネットワークの詳細設定'),
		-font => "TKFN",
		-foreground => 'blue'
	)->pack(-anchor => 'w', -pady => 2);

	# Edge選択
	$lf->Label(
		-text => $self->gui_jchar('描画する共起関係（edge）'),
		-font => "TKFN",
	)->pack(-anchor => 'w');

	my $f4 = $lf->Frame()->pack(
		-fill => 'x',
		-pady => 2
	);

	$f4->Label(
		-text => '  ',
		-font => "TKFN",
	)->pack(-anchor => 'w', -side => 'left');

	$self->{radio} = 'n';
	$f4->Radiobutton(
		-text             => $self->gui_jchar('描画数：'),
		-font             => "TKFN",
		-variable         => \$self->{radio},
		-value            => 'n',
		-command          => sub{ $self->refresh;},
	)->pack(-anchor => 'w', -side => 'left');

	$self->{entry_edges_number} = $f4->Entry(
		-font       => "TKFN",
		-width      => 3,
		-background => 'white',
	)->pack(-side => 'left', -padx => 2);
	$self->{entry_edges_number}->insert(0,'60');
	$self->{entry_edges_number}->bind("<Key-Return>",sub{$self->calc;});
	$self->config_entry_focusin($self->{entry_edges_number});

	$f4->Radiobutton(
		-text             => $self->gui_jchar('Jaccard係数：'),
		-font             => "TKFN",
		-variable         => \$self->{radio},
		-value            => 'j',
		-command          => sub{ $self->refresh;},
	)->pack(-anchor => 'w', -side => 'left');

	$self->{entry_edges_jac} = $f4->Entry(
		-font       => "TKFN",
		-width      => 4,
		-background => 'white',
	)->pack(-side => 'left', -padx => 2);
	$self->{entry_edges_jac}->insert(0,'0.2');
	$self->{entry_edges_jac}->bind("<Key-Return>",sub{$self->calc;});
	$self->config_entry_focusin($self->{entry_edges_jac});

	$f4->Label(
		-text => $self->gui_jchar('以上'),
		-font => "TKFN",
	)->pack(-anchor => 'w', -side => 'left');

	# Edgeの太さ・Nodeの大きさ
	$lf->Checkbutton(
			-text     => $self->gui_jchar('強い共起関係ほど太い線で描画','euc'),
			-variable => \$self->{check_use_weight_as_width},
			-anchor => 'w',
	)->pack(-anchor => 'w');

	$self->{wc_use_freq_as_size} = $lf->Checkbutton(
			-text     => $self->gui_jchar('出現数の多い語ほど大きい円で描画','euc'),
			-variable => \$self->{check_use_freq_as_size},
			-anchor   => 'w',
			-command  => sub{
				$self->{check_smaller_nodes} = 0;
				$self->refresh(3);
			},
	)->pack(-anchor => 'w');

	my $fontsize_frame = $lf->Frame()->pack(
		-fill => 'x',
		-pady => 0,
		-padx => 0,
	);

	$fontsize_frame->Label(
		-text => '  ',
		-font => "TKFN",
	)->pack(-anchor => 'w', -side => 'left');
	
	$self->{wc_use_freq_as_fsize} = $fontsize_frame->Checkbutton(
			-text     => $self->gui_jchar('フォントも大きく ※EMFやEPSでの出力・印刷向け','euc'),
			-variable => \$self->{check_use_freq_as_fsize},
			-anchor => 'w',
			-state => 'disabled',
	)->pack(-anchor => 'w');

	$self->{wc_smaller_nodes} = $lf->Checkbutton(
			-text     => $self->gui_jchar('すべての語を小さめの円で描画','euc'),
			-variable => \$self->{check_smaller_nodes},
			-anchor   => 'w',
			-command  => sub{
				$self->{check_use_freq_as_size} = 0;
				$self->refresh(3);
			},
	)->pack(-anchor => 'w');

	# フォントサイズ
	my $ff = $lf->Frame()->pack(
		-fill => 'x',
		-pady => 2,
	);

	$ff->Label(
		-text => $self->gui_jchar('フォントサイズ：'),
		-font => "TKFN",
	)->pack(-side => 'left');

	$self->{entry_font_size} = $ff->Entry(
		-font       => "TKFN",
		-width      => 3,
		-background => 'white',
	)->pack(-side => 'left', -padx => 2);
	$self->{entry_font_size}->insert(0,'80');
	$self->{entry_font_size}->bind("<Key-Return>",sub{$self->calc;});
	$self->config_entry_focusin($self->{entry_font_size});

	$ff->Label(
		-text => $self->gui_jchar('%'),
		-font => "TKFN",
	)->pack(-side => 'left');

	$ff->Label(
		-text => $self->gui_jchar('  プロットサイズ：'),
		-font => "TKFN",
	)->pack(-side => 'left');

	$self->{entry_plot_size} = $ff->Entry(
		-font       => "TKFN",
		-width      => 4,
		-background => 'white',
	)->pack(-side => 'left', -padx => 2);
	$self->{entry_plot_size}->insert(0,'640');
	$self->{entry_plot_size}->bind("<Key-Return>",sub{$self->calc;});
	$self->config_entry_focusin($self->{entry_plot_size});

	$win->Checkbutton(
			-text     => $self->gui_jchar('実行時にこの画面を閉じない','euc'),
			-variable => \$self->{check_rm_open},
			-anchor => 'w',
	)->pack(-anchor => 'w');

	$win->Button(
		-text => $self->gui_jchar('キャンセル'),
		-font => "TKFN",
		-width => 8,
		-command => sub{ $mw->after(10,sub{$self->close;});}
	)->pack(-side => 'right',-padx => 2, -pady => 2, -anchor => 'se');

	$win->Button(
		-text => 'OK',
		-width => 8,
		-font => "TKFN",
		-command => sub{ $mw->after(10,sub{$self->calc;});}
	)->pack(-side => 'right', -pady => 2, -anchor => 'se');

	$self->refresh(3);
	return $self;
}

sub refresh{
	my $self = shift;

	my (@dis, @nor);
	if ($self->{radio} eq 'n'){
		push @nor, $self->{entry_edges_number};
		push @dis, $self->{entry_edges_jac};
	} else {
		push @nor, $self->{entry_edges_jac};
		push @dis, $self->{entry_edges_number};
	}

	if ($self->{check_use_freq_as_size}){
		push @nor, $self->{wc_use_freq_as_fsize};
		push @dis, $self->{wc_smaller_nodes};
	} else {
		push @dis, $self->{wc_use_freq_as_fsize};
		push @nor, $self->{wc_smaller_nodes};
	}

	if ($self->{check_smaller_nodes}){
		push @dis, $self->{wc_use_freq_as_size};
		push @dis, $self->{wc_use_freq_as_fsize};
	} else {
		push @nor, $self->{wc_use_freq_as_size};
	}

	foreach my $i (@nor){
		$i->configure(-state => 'normal');
	}

	foreach my $i (@dis){
		$i->configure(-state => 'disabled');
	}
	
	$nor[0]->focus unless $_[0] == 3;
}

#----------#
#   実行   #

sub calc{
	my $self = shift;
	
	# 入力のチェック
	unless ( eval(@{$self->hinshi}) ){
		gui_errormsg->open(
			type => 'msg',
			msg  => '品詞が1つも選択されていません。',
		);
		return 0;
	}

	my $check_num = mysql_crossout::r_com->new(
		tani     => $self->tani,
		tani2    => $self->tani,
		hinshi   => $self->hinshi,
		max      => $self->max,
		min      => $self->min,
		max_df   => $self->max_df,
		min_df   => $self->min_df,
	)->wnum;
	
	$check_num =~ s/,//g;
	#print "$check_num\n";

	if ($check_num < 5){
		gui_errormsg->open(
			type => 'msg',
			msg  => '少なくとも5つ以上の抽出語を選択して下さい。',
		);
		return 0;
	}

	if ($check_num > 300){
		my $ans = $self->win_obj->messageBox(
			-message => $self->gui_jchar
				(
					 '現在の設定では'.$check_num.'語が分析に利用されます。'
					."\n"
					.'分析に用いる語の数は100〜150程度におさえることを推奨します。'
					."\n"
					.'続行してよろしいですか？'
				),
			-icon    => 'question',
			-type    => 'OKCancel',
			-title   => 'KH Coder'
		);
		unless ($ans =~ /ok/i){ return 0; }
	}

	$self->{words_obj}->settings_save;

	my $wait_window = gui_wait->start;

	# データの取り出し
	my $r_command = mysql_crossout::r_com->new(
		tani   => $self->tani,
		tani2  => $self->tani,
		hinshi => $self->hinshi,
		max    => $self->max,
		min    => $self->min,
		max_df => $self->max_df,
		min_df => $self->min_df,
		rownames => 0,
	)->run;

	# データ整理
	$r_command .= "d <- t(d)\n";
	$r_command .= "# END: DATA\n";

	my $fontsize = $self->gui_jg( $self->{entry_font_size}->get );
	$fontsize /= 100;

	&make_plot(
		font_size        => $fontsize,
		plot_size        => $self->gui_jg( $self->{entry_plot_size}->get ),
		n_or_j           => $self->gui_jg( $self->{radio} ),
		edges_num        => $self->gui_jg( $self->{entry_edges_number}->get ),
		edges_jac        => $self->gui_jg( $self->{entry_edges_jac}->get ),
		use_freq_as_size => $self->gui_jg( $self->{check_use_freq_as_size} ),
		use_freq_as_fsize=> $self->gui_jg( $self->{check_use_freq_as_fsize} ),
		smaller_nodes    => $self->gui_jg( $self->{check_smaller_nodes} ),
		use_weight_as_width =>
			$self->gui_jg( $self->{check_use_weight_as_width} ),
		r_command        => $r_command,
		plotwin_name     => 'word_netgraph',
	);

	$wait_window->end(no_dialog => 1);

	unless ( $self->{check_rm_open} ){
		$self->close;
	}

}

sub make_plot{
	my %args = @_;

	kh_r_plot->clear_env;

	my $r_command = $args{r_command};

	# パラメーター設定部分
	if ( $args{n_or_j} eq 'j'){
		$r_command .= "edges <- 0\n";
		$r_command .= "th <- $args{edges_jac}\n";
	}
	elsif ( $args{n_or_j} eq 'n'){
		$r_command .= "edges <- $args{edges_num}\n";
		$r_command .= "th <- 0\n";
	}
	$r_command .= "cex <- $args{font_size}\n";

	unless ( $args{use_freq_as_size} ){
		$args{use_freq_as_size} = 0;
	}
	$r_command .= "use_freq_as_size <- $args{use_freq_as_size}\n";

	unless ( $args{use_freq_as_fsize} && $args{use_freq_as_size}){
		$args{use_freq_as_fsize} = 0;
	}
	$r_command .= "use_freq_as_fontsize <- $args{use_freq_as_fsize}\n";

	unless ( $args{use_weight_as_width} ){
		$args{use_weight_as_width} = 0;
	}
	$r_command .= "use_weight_as_width <- $args{use_weight_as_width}\n";

	unless ( $args{smaller_nodes} ){
		$args{smaller_nodes} = 0;
	}
	$r_command .= "smaller_nodes <- $args{smaller_nodes}\n";

	$r_command .= &r_plot_cmd_p1;

	# プロット作成
	
	use Benchmark;
	my $t0 = new Benchmark;
	
	my $flg_error = 0;
	my $plot1 = kh_r_plot->new(
		name      => $args{plotwin_name}.'_1',
		command_f =>
			 $r_command
			."\ncom_method <- \"cnt-b\"\n"
			.&r_plot_cmd_p2
			.&r_plot_cmd_p3
			.&r_plot_cmd_p4,
		width     => $args{plot_size},
		height    => $args{plot_size},
	) or $flg_error = 1;

	my $plot2 = kh_r_plot->new(
		name      => $args{plotwin_name}.'_2',
		command_f =>
			 $r_command
			."\ncom_method <- \"cnt-d\"\n"
			.&r_plot_cmd_p2
			.&r_plot_cmd_p3
			.&r_plot_cmd_p4,
		command_a =>
			 "com_method <- \"cnt-d\"\n"
			.&r_plot_cmd_p2
			.&r_plot_cmd_p4,
		width     => $args{plot_size},
		height    => $args{plot_size},
	) or $flg_error = 1;

	my $plot3 = kh_r_plot->new(
		name      => $args{plotwin_name}.'_3',
		command_f =>
			 $r_command
			."\ncom_method <- \"com-b\"\n"
			.&r_plot_cmd_p2
			.&r_plot_cmd_p3
			.&r_plot_cmd_p4,
		command_a =>
			 "com_method <- \"com-b\"\n"
			.&r_plot_cmd_p2
			.&r_plot_cmd_p4,
		width     => $args{plot_size},
		height    => $args{plot_size},
	) or $flg_error = 1;

	my $plot4 = kh_r_plot->new(
		name      => $args{plotwin_name}.'_4',
		command_f =>
			 $r_command
			."\ncom_method <- \"com-g\"\n"
			.&r_plot_cmd_p2
			.&r_plot_cmd_p3
			.&r_plot_cmd_p4,
		command_a =>
			 "com_method <- \"com-g\"\n"
			.&r_plot_cmd_p2
			.&r_plot_cmd_p4,
		width     => $args{plot_size},
		height    => $args{plot_size},
	) or $flg_error = 1;

	my $plot5 = kh_r_plot->new(
		name      => $args{plotwin_name}.'_5',
		command_f =>
			 $r_command
			."\ncom_method <- \"none\"\n"
			.&r_plot_cmd_p2
			.&r_plot_cmd_p3
			.&r_plot_cmd_p4,
		command_a =>
			 "com_method <- \"none\"\n"
			.&r_plot_cmd_p2
			.&r_plot_cmd_p4,
		width     => $args{plot_size},
		height    => $args{plot_size},
	) or $flg_error = 1;

	my $t1 = new Benchmark;
	print timestr(timediff($t1,$t0)),"\n" if $bench;

	# 情報の取得（短いバージョン）
	my $info;
	$::config_obj->R->send('
		print(
			paste(
				"khcoderN ",
				length(get.vertex.attribute(n2,"name")),
				", E ",
				length(get.edgelist(n2,name=T)[,1]),
				", D ",
				substr(paste( round( graph.density(n2), 3 ) ), 2, 5 ),
				sep=""
			)
		)
	');
	$info = $::config_obj->R->read;
	if ($info =~ /"khcoder(.+)"/){
		$info = $1;
	} else {
		$info = undef;
	}

	# 情報の取得（長いバージョン）
	my $info_long;
	$::config_obj->R->send('
		print(
			paste(
				"khcoderNodes ",
				length(get.vertex.attribute(n2,"name")),
				" (",
				length(get.vertex.attribute(n,"name")),
				"), Edges ",
				length(get.edgelist(n2,name=T)[,1]),
				" (",
				length(get.edgelist(n,name=T)[,1]),
				"), Density ",
				substr(paste( round( graph.density(n2), 3 ) ), 2, 5 ),
				", Min. Jaccard ",
				substr( paste( round( th, 3 ) ), 2, 5),
				sep=""
			)
		)
	');
	$info_long = $::config_obj->R->read;
	if ($info_long =~ /"khcoder(.+)"/){
		$info_long = $1;
	} else {
		$info_long = undef;
	}

	# edgeの数・最小のjaccard係数などの情報をcommand_fに付加
	my ($info_edges, $info_jac);
	if ($info =~ /E ([0-9]+), D/){
		$info_edges = $1;
	}
	$::config_obj->R->send('print( paste( "khcoderJac", th, "ok", sep="" ) )');
	$info_jac = $::config_obj->R->read;
	if ($info_jac =~ /"khcoderJac(.+)ok"/){
		$info_jac = $1;
	}
	foreach my $i ($plot1, $plot2, $plot3, $plot4, $plot5){
		$i->{command_f} .= "\n# edges: $info_edges\n";
		$i->{command_f} .= "\n# min. jaccard: $info_jac\n";
	}

	# プロットWindowを開く
	kh_r_plot->clear_env;
	my $plotwin_id = 'w_'.$args{plotwin_name}.'_plot';
	if ($::main_gui->if_opened($plotwin_id)){
		$::main_gui->get($plotwin_id)->close;
	}
	
	return 0 if $flg_error;
	
	my $plotwin = 'gui_window::r_plot::'.$args{plotwin_name};
	$plotwin->open(
		plots       => [ $plot1, $plot2, $plot3, $plot4, $plot5],
		msg         => $info,
		msg_long    => $info_long,
		no_geometry => 1,
	);
	
	return 1;
}

sub r_plot_cmd_p1{
	return '

# 頻度計算
freq <- NULL
for (i in 1:length( rownames(d) )) {
	freq[i] = sum( d[i,] )
}

# 類似度計算 
d <- dist(d,method="binary")
d <- as.matrix(d)
d <- 1 - d;

# グラフ作成 
library(igraph)
n <- graph.adjacency(d, mode="lower", weighted=T, diag=F)
n <- set.vertex.attribute(
	n,
	"name",
	0:(length(d[1,])-1),
	as.character( 1:length(d[1,]) )
)

# edgeを間引く準備 
el <- data.frame(
	edge1            = get.edgelist(n,name=T)[,1],
	edge2            = get.edgelist(n,name=T)[,2],
	weight           = get.edge.attribute(n, "weight"),
	stringsAsFactors = FALSE
)

# 閾値を計算 
if (th == 0){
	if(edges > length(el[,1])){
		edges <- length(el[,1])
	}
	th = quantile(
		el$weight,
		names = F,
		probs = 1 - edges / length(el[,1])
	)
}

# edgeを間引いてグラフを再作成 
el2 <- subset(el, el[,3] >= th)
n2  <- graph.edgelist(
	matrix( as.matrix(el2)[,1:2], ncol=2 ),
	directed	=F
)
n2 <- set.edge.attribute(
	n2, "weight", 0:(length(get.edgelist(n2)[,1])-1), el2[,3]
)
	';
}

sub r_plot_cmd_p2{

return 
'
if (length(get.vertex.attribute(n2,"name")) < 2){
	com_method <- "none"
}

# 中心性
if ( com_method == "cnt-b" || com_method == "cnt-d"){
	if (com_method == "cnt-b"){                   # 媒介
		ccol <- betweenness(
			n2, v=0:(length(get.vertex.attribute(n2,"name"))-1), directed=F
		)
	}
	if (com_method == "cnt-d"){                   # 次数
		ccol <-  degree(n2, v=0:(length(get.vertex.attribute(n2,"name"))-1) )
	}
	ccol <- ccol - min(ccol)                      # 色の設定
	ccol <- ccol * 100 / max(ccol)
	ccol <- trunc(ccol + 1)
	ccol <- cm.colors(101)[ccol]
}

# クリーク検出
if ( com_method == "com-b" || com_method == "com-g"){
	merge_step <- function(n2, m){                # 共通利用の関数
		for ( i in 1:( trunc( length( m ) / 2 ) ) ){
			temp_csize <- community.to.membership(n2, m,i)$csize
			num_max   <- max( temp_csize )
			num_alone <- sum( temp_csize[ temp_csize == 1 ] )
			num_cls   <- length( temp_csize[temp_csize > 1] )
			#print( paste(i, "a", num_alone, "max", num_max, "cls", num_cls) )
			if (
				# 最大コミュニティサイズが全ノード数の22.5%以上
				   num_max / length(get.vertex.attribute(n2,"name")) >= 0.225
				# かつ、最大コミュニティサイズが単独ノード数よりも大きい
				&& num_max > num_alone
				# かつ、サイズが2以上のコミュニティ数が12未満
				&& num_cls < 12
			){
				return(i)
			}
			# 最大コミュニティサイズがノード数の40%を越える直前で打ち切り
			if (num_max / length(get.vertex.attribute(n2,"name")) >= 0.4 ){
				return(i-1)
			}
		}
		return( trunc(length( m ) / 2) )
	}

	if (com_method == "com-b"){                   # 媒介性（betweenness）
		com   <- edge.betweenness.community(n2, directed=F)    
		com_m <- community.to.membership(
			n2, com$merges, merge_step(n2,com$merges)
		)
	}

	if (com_method == "com-g"){                   # Modularity
		com   <- fastgreedy.community   (n2, merges=TRUE, modularity=TRUE)
		com_m <- community.to.membership(
			n2, com$merges, merge_step(n2,com$merges)
		)
	}

	com_col <- NULL # vertex frame                # Vertexの色（12色まで）
	ccol    <- NULL # vertex
	col_num <- 1
	library( RColorBrewer )
	for (i in com_m$csize ){
		if ( i == 1){
			ccol    <- c( ccol, "white" )
			com_col <- c( com_col, "gray40" )
		} else {
			if (col_num <= 12){
				ccol    <- c( ccol, brewer.pal(12, "Set3")[col_num] )
				com_col <- c( com_col, "gray40" )
			} else {
				ccol    <- c( ccol, "white" )
				com_col <- c( com_col, "blue" )
			}
			col_num <- col_num + 1
		}
	}
	com_col_v <- com_col[com_m$membership + 1]
	ccol      <- ccol[com_m$membership + 1]

	edg_lty <- NULL                               # edgeの色と形状
	edg_col <- NULL
	for (i in 1:length(el2$edge1)){
		if (
			   com_m$membership[ get.edgelist(n2,name=F)[i,1] + 1 ]
			== com_m$membership[ get.edgelist(n2,name=F)[i,2] + 1 ]
		){
			edg_col <- c( edg_col, "gray55" )
			edg_lty <- c( edg_lty, 1 )
		} else {
			edg_col <- c( edg_col, "gray" )
			edg_lty <- c( edg_lty, 3 )
		}
	}
} else { # 中心性でカラーリングする場合の線の色
	com_col_v <- "gray40"
	edg_col   <- "gray65"
	edg_lty   <- 1
}

# カラーリング「なし」の場合の線の色（2010 12/4）
if (com_method == "none"){
	com_col_v <- "black"
	if ( use_weight_as_width == 1 ){
		edg_lty <- 1
		edg_col   <- "gray40"
	} else {
		edg_lty <- 3
		edg_col   <- "black"
	}
}

if (com_method == "none"){
	ccol <- "white"
}
';

}


sub r_plot_cmd_p3{

return 
'
# 初期配置
if ( length(get.vertex.attribute(n2,"name")) >= 3 ){
	d4l <- as.dist( shortest.paths(n2) )
	if ( min(d4l) < 1 ){
		d4l <- as.dist( shortest.paths(n2, weights=NA ) )
	}
	if ( max(d4l) == Inf){
		d4l[d4l == Inf] <- vcount(n2)
	}
	lay <-  cmdscale( d4l, k=2 )
	check4fr <- function(d){
		chk <- 0
		for (i in combn( length(d[,1]), 2, simplify=F ) ){
			if (
				   d[i[1],1] == d[i[2],1]
				&& d[i[1],2] == d[i[2],2]
			){
				return( i[1] )
			}
		}
		return( NA )
	}
	while ( is.na(check4fr(lay)) == 0 ){
		mv <-  check4fr(lay)
		lay[mv,1] <- lay[mv,1] + 0.001
		#print( paste( "Moved:", mv ) )
	}
} else {
	lay <- NULL
}

# 配置
lay_f <- layout.fruchterman.reingold(n2,
	start   = lay,
	weights = get.edge.attribute(n2, "weight")
)

lay_f <- scale(lay_f)
lay_f[,1] <- lay_f[,1] / max( abs( lay_f[,1] ) )
lay_f[,2] <- lay_f[,2] / max( abs( lay_f[,2] ) )

# 負の値を0に変換する関数
neg_to_zero <- function(nums){
  temp <- NULL
  for (i in 1:length(nums) ){
    if (nums[i] < 0){
      temp[i] <- 0
    } else {
      temp[i] <-  nums[i]
    }
  }
  return(temp)
}

# vertex.sizeを計算
if ( use_freq_as_size == 1 ){
	v_size <- freq[ as.numeric( get.vertex.attribute(n2,"name") ) ]
	v_size <- v_size / sd(v_size)
	v_size <- v_size - mean(v_size)
	v_size <- v_size * 3 + 12 # 分散 = 3, 平均 = 12
	v_size <- neg_to_zero(v_size)
} else {
	v_size <- 15
}

# vertex.label.cexを計算
if ( use_freq_as_fontsize ==1 ){
	f_size <- freq[ as.numeric( get.vertex.attribute(n2,"name") ) ]
	f_size <- f_size / sd(f_size)
	f_size <- f_size - mean(f_size)
	f_size <- f_size * 0.2 + cex

	for (i in 1:length(f_size) ){
	  if (f_size[i] < 0.6 ){
	    f_size[i] <- 0.6
	  }
	}
} else {
	f_size <- cex
}

# 小さめの円で描画
if (smaller_nodes ==1){
	f_size <- cex
	v_size <- 5
	vertex_label_dist <- 0.75
} else {
	vertex_label_dist <- 0
}

# edge.widthを計算
if ( use_weight_as_width == 1 ){
	edg_width <- el2[,3]
	edg_width <- edg_width / sd( edg_width )
	edg_width <- edg_width - mean( edg_width )
	edg_width <- edg_width * 0.6 + 2 # 分散 = 0.5, 平均 = 2
	edg_width <- neg_to_zero(edg_width)
} else {
	edg_width <- 1
}

'
}

sub r_plot_cmd_p4{

return 
'
# 語の強調
v_shape    <- "circle"
target_ids <-  NULL
if ( exists("target_words") ){
	# IDの取得
	for (i in 1:length( get.vertex.attribute(n2,"name") ) ){
		for (w in target_words){
			if (
				colnames(d)[ as.numeric(get.vertex.attribute(n2,"name")[i]) ]
				== w
			){
				target_ids <- c(target_ids, i)
			}
		}
	}
	# 形状
	if (length(v_shape) == 1){
		v_shape <- rep(v_shape, length( get.vertex.attribute(n2,"name") ) )
	}
	v_shape[target_ids] <- "square"
	# 枠線の色
	if (length(com_col_v) == 1){
		com_col_v <- rep(com_col_v, length( get.vertex.attribute(n2,"name") ) )
	}
	com_col_v[target_ids] <- "black"
	# サイズ
	if (length( v_size ) == 1){
		v_size <- rep(v_size, length( get.vertex.attribute(n2,"name") ) )
	}
	v_size[target_ids] <- 15
	# 小さな円で描画している場合
	rect_size <- 0.095
	if (smaller_nodes == 1){
		# ラベルの距離
		if (length( vertex_label_dist ) == 1){
			vertex_label_dist <- rep(
				vertex_label_dist,
				length( get.vertex.attribute(n2,"name") )
			)
		}
		vertex_label_dist[target_ids] <- 0
		# サイズ
		if (length( v_size ) == 1){
			v_size <- rep(v_size, length( get.vertex.attribute(n2,"name") ) )
		}
		v_size[target_ids] <- 10
		rect_size <- 0.07
	}
}

# プロット
if (smaller_nodes ==1){
	par(mai=c(0,0,0,0), mar=c(0,0,1,1), omi=c(0,0,0,0), oma =c(0,0,0,0) )
} else {
	par(mai=c(0,0,0,0), mar=c(0,0,0,0), omi=c(0,0,0,0), oma =c(0,0,0,0) )
}
if ( length(get.vertex.attribute(n2,"name")) > 1 ){
	plot.igraph(
		n2,
		vertex.label       =colnames(d)
		                    [ as.numeric( get.vertex.attribute(n2,"name") ) ],
		vertex.label.cex   =f_size,
		vertex.label.color ="black",
		vertex.label.family= "", # Linux・Mac環境では必須
		vertex.label.dist  =vertex_label_dist,
		vertex.color       =ccol,
		vertex.frame.color =com_col_v,
		vertex.size        =v_size,
		vertex.shape       =v_shape,
		edge.color         =edg_col,
		edge.lty           =edg_lty,
		edge.width         =edg_width,
		layout             =lay_f,
		rescale            =F
	)

if ( exists("target_words") ){
	rect(
		lay_f[target_ids,1] - rect_size, lay_f[target_ids,2] - rect_size,
		lay_f[target_ids,1] + rect_size, lay_f[target_ids,2] + rect_size,
	)
}
}
'
}

#--------------#
#   アクセサ   #

sub label{
	return '抽出語・共起ネットワーク：オプション';
}

sub win_name{
	return 'w_word_netgraph';
}

sub min{
	my $self = shift;
	return $self->{words_obj}->min;
}
sub max{
	my $self = shift;
	return $self->{words_obj}->max;
}
sub min_df{
	my $self = shift;
	return $self->{words_obj}->min_df;
}
sub max_df{
	my $self = shift;
	return $self->{words_obj}->max_df;
}
sub tani{
	my $self = shift;
	return $self->{words_obj}->tani;
}
sub hinshi{
	my $self = shift;
	return $self->{words_obj}->hinshi;
}

1;