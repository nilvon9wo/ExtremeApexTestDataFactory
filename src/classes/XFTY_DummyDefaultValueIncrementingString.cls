@IsTest
public class XFTY_DummyDefaultValueIncrementingString implements XFTY_DummyDefaultValueIntf {
    private String prefix;
    private Integer counter = 1;

    public XFTY_DummyDefaultValueIncrementingString(String prefix) {
        this.prefix = prefix;
    }

    public Object get() {
        return this.prefix + ' ' + counter++;
    }
}