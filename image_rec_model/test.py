import tensorflow as tf
import numpy as np
from PIL import Image
import os

# 参数设置
IMG_HEIGHT = 224  # 与训练时一致
IMG_WIDTH = 224   # 与训练时一致
MODEL_PATH = 'model.tflite'
LABELS_PATH = 'labels.txt'
IMAGE_PATH = '1.jpg'

# 1. 加载标签
def load_labels():
    if not os.path.exists(LABELS_PATH):
        raise FileNotFoundError(f"Labels file not found at {LABELS_PATH}")
    with open(LABELS_PATH, 'r') as f:
        labels = [line.strip() for line in f.readlines()]
    return labels

# 2. 预处理图像
def preprocess_image(image_path):
    # 加载图像
    img = Image.open(image_path).convert('RGB')
    # 调整大小
    img = img.resize((IMG_WIDTH, IMG_HEIGHT))
    # 转换为 numpy 数组并归一化
    img_array = np.array(img, dtype=np.float32) / 255.0
    # 增加 batch 维度 (1, height, width, channels)
    img_array = np.expand_dims(img_array, axis=0)
    return img_array

# 3. 推理
def run_inference(interpreter, input_data):
    # 设置输入张量
    input_details = interpreter.get_input_details()
    interpreter.set_tensor(input_details[0]['index'], input_data)

    # 运行推理
    interpreter.invoke()

    # 获取输出张量
    output_details = interpreter.get_output_details()
    output_data = interpreter.get_tensor(output_details[0]['index'])
    return output_data

# 4. 主函数
def main():
    # 加载标签
    labels = load_labels()
    print(f"Loaded labels: {labels}")

    # 加载 TFLite 模型
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
    interpreter.allocate_tensors()
    print("Model loaded successfully")

    # 预处理图像
    input_image = preprocess_image(IMAGE_PATH)
    print(f"Input image shape: {input_image.shape}")

    # 运行推理
    output = run_inference(interpreter, input_image)

    # 获取分类结果
    predicted_class = np.argmax(output[0])
    confidence = output[0][predicted_class]
    predicted_label = labels[predicted_class]

    # 输出结果
    print(f"Predicted class: {predicted_label}")
    print(f"Confidence: {confidence:.4f}")
    print("All probabilities:")
    for i, prob in enumerate(output[0]):
        print(f"{labels[i]}: {prob:.4f}")

if __name__ == "__main__":
    main()