

inl hash_t hash(u32 x){
	u32 PRIME_0 = 0x9E3779B1u;
	u32 PRIME_1 = 0x85EBCA77u;
	u32 PRIME_2 = 0xC2B2AE3Du;
	u32 PRIME_3 = 0x27D4EB2Fu;

	u32 a0= x*PRIME_0;
	u32 a1= x*PRIME_1;
	u32 a2= x*PRIME_2;
	u32 a3= x*PRIME_3;
		x= a0^a1;
	u64 y= a2^a3;
	y^= (y<<16)|(y>>16);
	x^= y;
	re x;
}
inl hash_t hash(u64 x){
	u64 PRIME_0 = 0xC43A65E071D385B1ull;
	u64 PRIME_1 = 0x9A232294BAEEBB27ull;
	u64 PRIME_2 = 0xAC0671A220DFABF7ull;
	u64 PRIME_3 = 0xB59BC8E3F34FFF6Bull;

	u64 a0= x*PRIME_0;
	u64 a1= x*PRIME_1;
	u64 a2= x*PRIME_2;
	u64 a3= x*PRIME_3;
		x= a0^a1;
	u64 y= a2^a3;
	y^= (y<<32)|(y>>32);
	x^= y;
	re x;
}
inl hash_t hash(void* x){ re hash((u64) x); };
inl hash_t hash(i32   x){ re hash((u32) x); };
inl hash_t hash(i64   x){ re hash((u64) x); };

inl u32 rand(u32 x){
	re hash(x);
}
inl float rand(float in){
	re (float)rand(rcas<u32>(in)) / (float)INTMAX<u32>;
}


