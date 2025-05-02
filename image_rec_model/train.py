import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import os
import numpy as np

# 参数设置
IMG_HEIGHT = 224
IMG_WIDTH = 224
BATCH_SIZE = 32
EPOCHS = 10
DATASET_DIR = './dataset'
MODEL_DIR = './model/model.keras'  # 修改为带有 .keras 扩展名的文件路径
TFLITE_MODEL_PATH = 'model.tflite'
LABELS_PATH = 'labels.txt'

# 1. 加载和预处理数据集
def load_dataset():
    train_datagen = ImageDataGenerator(
        rescale=1./255,
        rotation_range=20,
        width_shift_range=0.2,
        height_shift_range=0.2,
        shear_range=0.2,
        zoom_range=0.2,
        horizontal_flip=True,
        fill_mode='nearest',
        validation_split=0.2
    )

    train_generator = train_datagen.flow_from_directory(
        DATASET_DIR,
        target_size=(IMG_HEIGHT, IMG_WIDTH),
        batch_size=BATCH_SIZE,
        class_mode='categorical',
        subset='training'
    )

    validation_generator = train_datagen.flow_from_directory(
        DATASET_DIR,
        target_size=(IMG_HEIGHT, IMG_WIDTH),
        batch_size=BATCH_SIZE,
        class_mode='categorical',
        subset='validation'
    )

    return train_generator, validation_generator

# 2. 构建 CNN 模型
def build_model(num_classes):
    model = models.Sequential([
        layers.Conv2D(32, (3, 3), activation='relu', input_shape=(IMG_HEIGHT, IMG_WIDTH, 3)),
        layers.MaxPooling2D((2, 2)),
        layers.Conv2D(64, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        layers.Conv2D(128, (3, 3), activation='relu'),
        layers.MaxPooling2D((2, 2)),
        layers.Flatten(),
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.5),
        layers.Dense(num_classes, activation='softmax')
    ])
    return model

# 3. 保存标签文件
def save_labels(labels):
    with open(LABELS_PATH, 'w') as f:
        for label in labels:
            f.write(f"{label}\n")

# 4. 主函数
def main():
    # 加载数据集
    train_generator, validation_generator = load_dataset()
    num_classes = len(train_generator.class_indices)
    labels = list(train_generator.class_indices.keys())
    
    # 保存标签
    save_labels(labels)
    print(f"Labels saved to {LABELS_PATH}: {labels}")

    # 构建和编译模型
    model = build_model(num_classes)
    model.compile(
        optimizer='adam',
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    model.summary()

    # 训练模型
    history = model.fit(
        train_generator,
        epochs=EPOCHS,
        validation_data=validation_generator
    )

    # 保存模型为 .keras 格式
    os.makedirs(os.path.dirname(MODEL_DIR), exist_ok=True)  # 确保目录存在
    model.save(MODEL_DIR)
    print(f"Model saved to {MODEL_DIR}")

    # 转换为 TFLite 模型
    converter = tf.lite.TFLiteConverter.from_keras_model(model)  # 直接从模型加载
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    # 保存 TFLite 模型
    with open(TFLITE_MODEL_PATH, 'wb') as f:
        f.write(tflite_model)
    print(f"TFLite model saved to {TFLITE_MODEL_PATH}")

if __name__ == "__main__":
    main()