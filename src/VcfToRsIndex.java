import java.io.File;
import java.util.List;
import java.util.Vector;
import java.util.concurrent.Callable;

import genepi.io.table.writer.CsvTableWriter;
import genepi.io.table.writer.ExcelTableWriter;
import genepi.io.table.writer.ITableWriter;
import genepi.io.text.LineWriter;
import htsjdk.variant.variantcontext.Allele;
import htsjdk.variant.variantcontext.VariantContext;
import htsjdk.variant.vcf.VCFFileReader;
import picocli.CommandLine;
import picocli.CommandLine.Option;

//usr/bin/env jbang "$0" "$@" ; exit $?
//REPOS jcenter,jfrog-genepi-maven=https://genepi.jfrog.io/artifactory/maven
//DEPS info.picocli:picocli:4.5.0
//DEPS genepi:genepi-io:1.0.12
//DEPS com.github.samtools:htsjdk:2.21.3

public class VcfToRsIndex implements Callable<Integer> {

	@Option(names = "--input", description = "input vcf file", required = true)
	private String input;

	@Option(names = "--output", description = "output file", required = true)
	private String output;

	public void setInput(String input) {
		this.input = input;
	}

	public void setOutput(String output) {
		this.output = output;
	}

	public static void main(String... args) {
		int exitCode = new CommandLine(new VcfToRsIndex()).execute(args);
		System.exit(exitCode);
	}

	@Override
	public Integer call() throws Exception {

		assert (input != null);
		assert (output != null);

		VCFFileReader reader = new VCFFileReader(new File(input), false);

		LineWriter writer = new LineWriter(output);


		for (VariantContext variant : reader) {

			if (variant.getID().startsWith("rs")) {
				String contig = VcfToRsIndex.getContig(variant.getID());
				int position = VcfToRsIndex.getPosition(variant.getID());
				writer.write(contig + "\t" + position + "\t" + variant.getContig() + "\t" + variant.getStart() + "\t"
						+ variant.getReference().getBaseString() + "\t"	+ VcfToRsIndex.joinAlleles(variant.getAlternateAlleles()));
			}
		}

		writer.close();
		reader.close();

		return 0;
	}


	public static String getContig(String rsID) {
		if (rsID.length() > 10) {
			return rsID.substring(0, 3);
		} else {
			return "rs";
		}
	}

	public static int getPosition(String rsID) {
		if (rsID.length() > 10) {
			return Integer.parseInt(rsID.substring(3));
		} else {
			return Integer.parseInt(rsID.substring(2));
		}
	}

	public static String joinAlleles(List<Allele> alleles) {
		String result = "";
		for (int  i= 0; i < alleles.size(); i++) {
			if (i > 0) {
				result+=",";
			}
			result += alleles.get(i).getBaseString();
		}
		return result;
	}

}
