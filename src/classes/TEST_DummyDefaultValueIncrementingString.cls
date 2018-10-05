@IsTest
public class TEST_DummyDefaultValueIncrementingString implements TEST_DummyDefaultValueIntf {
    private String prefix; 
    private Integer counter = 1;
    
    public TEST_DummyDefaultValueIncrementingString(String prefix) {
    	this.prefix = prefix;
    } 
    
    public Object get() {
    	return this.prefix + ' ' + counter++;
    } 
}