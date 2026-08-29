@IsTest
public class XFTY_DummyDefaultValueUniqueStringLength implements XFTY_DummyDefaultValueIntf {
	private static final Map<Integer, Integer> LENGTH_TO_COUNTER = new Map<Integer, Integer>();
	private static final Integer A_ASCII_CODE = 65;
	private static final Integer ALPHABET_LENGTH = 26;
	private final Integer length;

	public XFTY_DummyDefaultValueUniqueStringLength(Integer length) {
		this.length = length;
		if (!LENGTH_TO_COUNTER.containsKey(this.length)) {
			LENGTH_TO_COUNTER.put(this.length, 0);
		}
	}

	public Object get() {
		Integer counter = LENGTH_TO_COUNTER.get(this.length);
		String nextString = this.generateNextString(counter++);
		LENGTH_TO_COUNTER.put(this.length, counter);
		return nextString;
	}

	public String generateNextString(Integer counter) {
		List<Integer> value = new List<Integer>();
		Integer quotient = counter;
		for (Integer i = 0; i < this.length; i++) {
			value.add(A_ASCII_CODE + Math.mod(quotient, ALPHABET_LENGTH));
			quotient = quotient / ALPHABET_LENGTH;
		}
		return String.fromCharArray(value);
	}
}