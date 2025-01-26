/* Quartus Prime Version 23.1std.1 Build 993 05/14/2024 SC Lite Edition */
JedecChain;
	FileRevision(JESD32A);
	DefaultMfr(6E);

	P ActionCode(Ign)
		Device PartName(SOCVHPS) MfrSpec(OpMask(0));
	P ActionCode(Ign)
		Device PartName(5CSEMA5) MfrSpec(OpMask(0) SEC_Device(QSPI128MB) Child_OpMask(1 128));

ChainEnd;

AlteraBegin;
	ChainType(JTAG);
AlteraEnd;
