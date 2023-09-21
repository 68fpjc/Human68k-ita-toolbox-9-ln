* ln - make links
*
* Itagaki Fumihiko 27-Aug-92  Create.
* 1.0
* Itagaki Fumihiko 06-Nov-92  strip_excessive_slashes �̃o�Ofix�ɔ������ŁD
*                             ���ׂȃ��b�Z�[�W�ύX�D
* 1.1
*
* Usage: ln [ -fisv ] source target
*        ln [ -fisv ] source ... targetdir

.include doscall.h
.include error.h
.include limits.h
.include stat.h
.include chrcode.h

.xref DecodeHUPAIR
.xref issjis
.xref strlen
.xref strfor1
.xref headtail
.xref cat_pathname
.xref strip_excessive_slashes
.xref fclose

STACKSIZE	equ	512
GETSLEN		equ	32

FLAG_s		equ	0
FLAG_i		equ	1
FLAG_f		equ	2
FLAG_v		equ	3

.text
start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	stack_bottom,a7			*  A7 := �X�^�b�N�̒�
		DOS	_GETPDB
		movea.l	d0,a0				*  A0 : PDB�A�h���X
		move.l	a7,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
	*  �������ъi�[�G���A���m�ۂ���
	*
		lea	1(a2),a0			*  A0 := �R�}���h���C���̕�����̐擪�A�h���X
		bsr	strlen				*  D0.L := �R�}���h���C���̕�����̒���
		addq.l	#1,d0
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := �������ъi�[�G���A�̐擪�A�h���X
	*
	*  �������f�R�[�h���C���߂���
	*
		bsr	DecodeHUPAIR			*  �������f�R�[�h����
		movea.l	a1,a0				*  A0 : �����|�C���^
		move.l	d0,d7				*  D7.L : �����J�E���^
		moveq	#0,d5				*  D5.L : option
decode_opt_loop1:
		tst.l	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a0)
		bne	decode_opt_done

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		beq	decode_opt_done
decode_opt_loop2:
		cmp.b	#'i',d0
		beq	set_option_i

		cmp.b	#'f',d0
		beq	set_option_f

		moveq	#FLAG_s,d1
		cmp.b	#'s',d0
		beq	set_option

		moveq	#FLAG_v,d1
		cmp.b	#'v',d0
		beq	set_option

		moveq	#1,d1
		tst.b	(a0)
		beq	bad_option_1

		bsr	issjis
		bne	bad_option_1

		moveq	#2,d1
bad_option_1:
		move.l	d1,-(a7)
		pea	-1(a0)
		move.w	#2,-(a7)
		lea	msg_illegal_option(pc),a0
		bsr	werror_myname_and_msg
		DOS	_WRITE
		lea	10(a7),a7
		bra	usage

set_option_f:
		bset	#FLAG_f,d5
		bclr	#FLAG_i,d5
		bra	set_option_done

set_option_i:
		bset	#FLAG_i,d5
		bclr	#FLAG_f,d5
		bra	set_option_done

set_option:
		bset	d1,d5
set_option_done:
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
		moveq	#0,d6				*  D6.W : �G���[�E�R�[�h
		subq.l	#2,d7
		bcs	too_few_args			*  ���������� -> �G���[
	*
	*  target�𒲂ׂ�
	*
		movea.l	a0,a1				*  A1 : 1st source
		move.l	d7,d0
find_target:
		bsr	strfor1
		subq.l	#1,d0
		bcc	find_target
							*  A0 : target
		bsr	strip_excessive_slashes
		bsr	is_directory
		bmi	exit_program
		bne	ln_into_dir

		*  target �̓f�B���N�g���ł͂Ȃ�

		tst.l	d7
		bne	bad_destination			*  ������ 3�ȏ� -> �G���[
	*
	*  ln [ -s ] source target
	*
		exg	a0,a1				*  A0 : source, A1 : target
		bsr	strip_excessive_slashes
		bsr	create_symlink
		bra	exit_program
****************
ln_into_dir:
	*
	*  ln [ -s ] file ... dir
	*
		exg	a0,a1				*  A0 : 1st source, A1 : target
ln_into_dir_loop:
		movea.l	a0,a2
		bsr	strfor1
		exg	a0,a2				*  A2 : next arg
		bsr	strip_excessive_slashes
		bsr	create_symlink_into_dir
ln_into_dir_continue:
		movea.l	a2,a0
		subq.l	#1,d7
		bcc	ln_into_dir_loop
exit_program:
		move.w	d6,-(a7)
		DOS	_EXIT2

bad_destination:
		lea	msg_not_a_directory(pc),a2
		bsr	lgetmode
		bpl	ln_error_exit

		lea	msg_nodir(pc),a2
ln_error_exit:
		bsr	werror_myname_word_colon_msg
		bra	exit_program

too_few_args:
		lea	msg_too_few_args(pc),a0
		bsr	werror_myname_and_msg
usage:
		lea	msg_usage(pc),a0
		bsr	werror
		moveq	#1,d6
		bra	exit_program

insufficient_memory:
		lea	msg_no_memory(pc),a0
ln_error_exit_3:
		bsr	werror_myname_and_msg
		moveq	#3,d6
		bra	exit_program
*****************************************************************
* create_symlink_into_dir
*
*      A0 �Ŏ������G���g�����w���V���{���b�N�E�����N��
*      A1 �Ŏ������f�B���N�g�����ɍ쐬����
*
* RETURN
*      none
*****************************************************************
target = -((((MAXPATH+1)+1)>>1)<<1)

create_symlink_into_dir:
		link	a6,#target
		movem.l	d0-d2/a0-a2,-(a7)
		movea.l	a1,a2
		bsr	headtail
		exg	a1,a2				*  A2 : tail of source
		move.l	a0,-(a7)
		lea	target(a6),a0
		bsr	cat_pathname_x
		movea.l	(a7)+,a1
		bmi	create_symlink_into_dir_done

		exg	a0,a1
		bsr	create_symlink
create_symlink_into_dir_done:
		movem.l	(a7)+,d0-d2/a0-a2
		unlk	a6
create_symlink_return:
		rts
*****************************************************************
* create_symlink_into_cwd
*
*      A0 �Ŏ������p�X���w���V���{���b�N�E�����N��
*      ��ƃf�B���N�g�����ɍ쐬����
*
* RETURN
*      D0-D2/A0-A2  �j��
*****************************************************************
*****************************************************************
* create_symlink
*
*      A0 �Ŏ������p�X���w���V���{���b�N�E�����N��
*      A1 �Ŏ������p�X���ō쐬����
*
* RETURN
*      D0-D2/A0-A2  �j��
*****************************************************************
create_symlink_into_cwd:
		bsr	headtail			*  A1 := tail
create_symlink:
		exg	a0,a1
		bsr	lgetmode
		bmi	target_ok

		lea	msg_cannot_overwrite(pc),a2
		btst	#MODEBIT_DIR,d0
		bne	werror_myname_word_colon_msg

		btst	#MODEBIT_VOL,d0
		bne	werror_myname_word_colon_msg

		move.w	d0,d1
		moveq	#EWRITE,d0			*  File exists.
		btst	#FLAG_f,d5
		bne	force

		btst	#FLAG_i,d5
		beq	perror

		bsr	confirm
		bne	create_symlink_return
force:
		move.w	#MODEVAL_ARC,-(a7)
		move.l	a0,-(a7)
		DOS	_CHMOD
		DOS	_DELETE
		addq.l	#6,a7
target_ok:
		btst	#FLAG_v,d5
		beq	verbose_done

		move.l	a1,-(a7)
		DOS	_PRINT
		pea	msg_arrow(pc)
		DOS	_PRINT
		move.l	a0,(a7)
		DOS	_PRINT
		pea	msg_newline(pc)
		DOS	_PRINT
		lea	12(a7),a7
verbose_done:
		move.w	#(MODEVAL_LNK|MODEVAL_ARC),-(a7)
		move.l	a0,-(a7)			*  target file ��
		DOS	_CREATE				*  �쐬����
		addq.l	#6,a7				*  �i�h���C�u�̌����͍ς�ł���j
		move.l	d0,d1
		bmi	perror

		exg	a0,a1
		bsr	strlen
		exg	a0,a1
		move.l	d0,d2
		move.l	d2,-(a7)
		move.l	a1,-(a7)
		move.w	d1,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	create_symlink_perror

		cmp.l	d2,d0
		bhs	create_symlink_done

		moveq	#EDISKFULL,d0
create_symlink_perror:
		bsr	perror
		bra	create_symlink_done
create_symlink_done:
		move.l	d1,d0
		bra	fclose
*****************************************************************
confirm:
		move.l	a0,-(a7)
		bsr	werror
		lea	msg_confirm(pc),a0
		bsr	werror
		lea	getsbuf(pc),a0
		move.b	#GETSLEN,(a0)
		move.l	a0,-(a7)
		DOS	_GETS
		addq.l	#4,a7
		bsr	werror_newline
		moveq	#1,d0
		tst.b	1(a0)
		beq	confirm_done

		cmpi.b	#'y',2(a0)
		bne	confirm_done

		moveq	#0,d0
confirm_done:
		movea.l	(a7)+,a0
		tst.l	d0
		rts
*****************************************************************
* cat_pathname_x
*
* RETURN
*      A2     �j��
*****************************************************************
cat_pathname_x:
		bsr	cat_pathname
		bpl	cat_pathname_x_return

		lea	msg_too_long_pathname(pc),a2
		bsr	werror_myname_word_colon_msg
		tst.l	d0
cat_pathname_x_return:
		rts
*****************************************************************
lgetmode:
		move.w	#-1,-(a7)
		move.l	a0,-(a7)
		DOS	_CHMOD
		addq.l	#6,a7
		tst.l	d0
		rts
*****************************************************************
* is_directory - ���O���f�B���N�g���ł��邩�ǂ����𒲂ׂ�
*
* CALL
*      A0     ���O
*
* RETURN
*      D0.L   ���O/*.* ����������Ȃ�� -1�D
*             ���̂Ƃ��G���[���b�Z�[�W���\������CD6.L �ɂ� 2 ���Z�b�g�����D
*
*             �����łȂ���΁C���O���f�B���N�g���Ȃ�� 1�C�����Ȃ��� 0
*
*      CCR    TST.L D0
*****************************************************************
is_directory:
		movem.l	a0-a3,-(a7)
		tst.b	(a0)
		beq	is_directory_false

		movea.l	a0,a1
		lea	pathname_buf(pc),a0
		lea	dos_wildcard_all(pc),a2
		bsr	cat_pathname_x
		bmi	is_directory_return

		move.w	#MODEVAL_ALL,-(a7)		*  ���ׂẴG���g������������
		move.l	a0,-(a7)
		pea	filesbuf(pc)
		DOS	_FILES
		lea	10(a7),a7
		tst.l	d0
		bpl	is_directory_true

		cmp.l	#ENOFILE,d0
		beq	is_directory_true
is_directory_false:
		moveq	#0,d0
		bra	is_directory_return

is_directory_true:
		moveq	#1,d0
is_directory_return:
		movem.l	(a7)+,a0-a3
		rts
*****************************************************************
werror_myname_and_msg:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
werror:
		movem.l	d0/a1,-(a7)
		movea.l	a0,a1
werror_1:
		tst.b	(a1)+
		bne	werror_1

		subq.l	#1,a1
		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		movem.l	(a7)+,d0/a1
		rts
*****************************************************************
werror_newline:
		move.l	a0,-(a7)
		lea	msg_newline(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		rts
*****************************************************************
werror_myname_word_colon_msg:
		bsr	werror_myname_and_msg
		move.l	a0,-(a7)
		lea	msg_colon(pc),a0
werror_word_msg_and_set_error:
		bsr	werror
		movea.l	a2,a0
		bsr	werror
		movea.l	(a7)+,a0
		bsr	werror_newline
		moveq	#2,d6
		rts
*****************************************************************
perror:
		movem.l	d0/a2,-(a7)
		not.l	d0		* -1 -> 0, -2 -> 1, ...
		cmp.l	#25,d0
		bls	perror_2

		moveq	#0,d0
perror_2:
		lea	perror_table(pc),a2
		lsl.l	#1,d0
		move.w	(a2,d0.l),d0
		lea	sys_errmsgs(pc),a2
		lea	(a2,d0.w),a2
		bsr	werror_myname_word_colon_msg
		movem.l	(a7)+,d0/a2
		tst.l	d0
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## ln 1.1 ##  Copyright(C)1992 by Itagaki Fumihiko',0

.even
perror_table:
	dc.w	msg_error-sys_errmsgs			*   0 ( -1)
	dc.w	msg_nofile-sys_errmsgs			*   1 ( -2)
	dc.w	msg_nopath-sys_errmsgs			*   2 ( -3)
	dc.w	msg_too_many_openfiles-sys_errmsgs	*   3 ( -4)
	dc.w	msg_cannot_create-sys_errmsgs		*   4 ( -5)
	dc.w	msg_error-sys_errmsgs			*   5 ( -6)
	dc.w	msg_error-sys_errmsgs			*   6 ( -7)
	dc.w	msg_error-sys_errmsgs			*   7 ( -8)
	dc.w	msg_error-sys_errmsgs			*   8 ( -9)
	dc.w	msg_error-sys_errmsgs			*   9 (-10)
	dc.w	msg_error-sys_errmsgs			*  10 (-11)
	dc.w	msg_error-sys_errmsgs			*  11 (-12)
	dc.w	msg_bad_name-sys_errmsgs		*  12 (-13)
	dc.w	msg_error-sys_errmsgs			*  13 (-14)
	dc.w	msg_bad_drive-sys_errmsgs		*  14 (-15)
	dc.w	msg_error-sys_errmsgs			*  15 (-16)
	dc.w	msg_error-sys_errmsgs			*  16 (-17)
	dc.w	msg_error-sys_errmsgs			*  17 (-18)
	dc.w	msg_cannot_create-sys_errmsgs		*  18 (-19)
	dc.w	msg_error-sys_errmsgs			*  19 (-20)
	dc.w	msg_error-sys_errmsgs			*  20 (-21)
	dc.w	msg_error-sys_errmsgs			*  21 (-22)
	dc.w	msg_disk_full-sys_errmsgs		*  22 (-23)
	dc.w	msg_directory_full-sys_errmsgs		*  23 (-24)
	dc.w	msg_error-sys_errmsgs			*  24 (-25)
	dc.w	msg_error-sys_errmsgs			*  25 (-26)

sys_errmsgs:
msg_error:		dc.b	'�G���[',0
msg_nofile:		dc.b	'���̂悤�ȃt�@�C���͂���܂���',0
msg_nopath:		dc.b	'�p�X�����݂��Ă��܂���',0
msg_too_many_openfiles:	dc.b	'�I�[�v�����Ă���t�@�C�����������܂�',0
msg_bad_name:		dc.b	'���O�������ł�',0
msg_bad_drive:		dc.b	'�h���C�u�̎w�肪�����ł�',0
msg_cannot_create:	dc.b	'�t�@�C�������݂��Ă��܂�',0
msg_directory_full:	dc.b	'�f�B���N�g�������t�ł�',0
msg_disk_full:		dc.b	'�f�B�X�N�����t�ł�',0

msg_myname:		dc.b	'ln'
msg_colon:		dc.b	': ',0
msg_no_memory:		dc.b	'������������܂���',CR,LF,0
msg_illegal_option:	dc.b	'�s���ȃI�v�V���� -- ',0
msg_too_few_args:	dc.b	'����������܂���',0
msg_too_long_pathname:	dc.b	'�p�X�������߂��܂�',0
msg_not_a_directory:	dc.b	'�f�B���N�g���ł͂���܂���',0
msg_nodir:		dc.b	'���̂悤�ȃf�B���N�g���͂���܂���',0
msg_confirm:		dc.b	' ���������Ă�낵���ł����H ',0
msg_cannot_overwrite:	dc.b	'�f�B���N�g����{�����[���E���x���ɂ͏������߂܂���',0
msg_usage:		dc.b	CR,LF
			dc.b	'�g�p�@:  ln [-fisv] [-] <���O> <�쐬�����N��>',CR,LF
			dc.b	'         ln [-fisv] [-] <���O> ... <�쐬��f�B���N�g��>'
msg_newline:		dc.b	CR,LF,0
msg_arrow:		dc.b	' -> ',0
dos_wildcard_all:	dc.b	'*.*',0
*****************************************************************
.bss

.even
filesbuf:		ds.b	STATBUFSIZE
.even
getsbuf:		ds.b	2+GETSLEN+1
pathname_buf:		ds.b	128
.even
			ds.b	STACKSIZE
.even
stack_bottom:
*****************************************************************

.end start
