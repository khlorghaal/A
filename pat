diff --git a/main.c b/main.c
--- a/main.c
+++ b/main.c
@@ -37,6 +37,13 @@ typedef u32 rgb;
 i2 sdim;//screen dimension
 i2 view= {0,0};
 
+cst rgb col_ship_fg=0xeeeeee;
+cst rgb col_base_fg=0xfafafa;
+cst rgb col_base_bg=0x020202;
+cst rgb col_dpad_fg=0x111111;
+cst rgb col_dpad_bg=0x444444;
+cst rgb col_dbg_fg =0x000000;
+cst rgb col_dbg_bg =0x00ee00;
+
 static uintattr_t col(rgb c){
 	return TB_RGB(c>>16,(c>>8)&255,c&255);
 }
@@ -107,7 +114,7 @@ static void draw(i2 m, wch c){
 	i2 v=m-view+sdim/2;
-	tb_set_cell(v.x,v.y,(uint32_t)c,col(0xeeeeee),col(0x020202));
+	tb_set_cell(v.x,v.y,(uint32_t)c,col(col_ship_fg),col(col_base_bg));
 }
 
 char* dbgp="init";
@@ -123,7 +130,7 @@ int main(void){
 		return 1;
 
 	tb_set_input_mode(TB_INPUT_ESC|TB_INPUT_MOUSE);
-	tb_set_clear_attrs(col(0xfafafa),col(0x020202));
+	tb_set_clear_attrs(col(col_base_fg),col(col_base_bg));
 	tb_hide_cursor();
 	tb_clear();
 
@@ -179,8 +186,7 @@ int main(void){
 			ra(i,7)
 				ra(j,7)
-					tb_set_cell(pad_o.x+j,pad_o.y+i,(uint32_t)l[i][j],
-						col(0x111111),col(0x444444));
+					tb_set_cell(pad_o.x+j,pad_o.y+i,(uint32_t)l[i][j],col(col_dpad_fg),col(col_dpad_bg));
 
 			i2 dp= mau-pad_o;
 			if(isbound(dp, 0,pad_wh)){
@@ -218,7 +224,7 @@ int main(void){
 		//header
 		if(dbgdur-->0){
-			tb_print(0,0,col(0x000000),col(0x00ee00),dbgp);
+			tb_print(0,0,col(col_dbg_fg),col(col_dbg_bg),dbgp);
 		}
