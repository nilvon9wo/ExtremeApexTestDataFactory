@IsTest
public class TEST_DummyDefaultValueExact implements TEST_DummyDefaultValueIntf {
    private Object value;
    
    public TEST_DummyDefaultValueExact(Object value) {
    	this.value = value;
    } 
    
    public Object get() {
    	return this.value;
    }
}